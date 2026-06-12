#!/usr/bin/env python3
"""
nnclinssoap AWS infrastructure setup script
============================================
Sets up a single EC2 On-Demand instance (r6i.4xlarge, 16 vCPU / 128 GB) for pipeline benchmarking.
Run with:  python aws_setup.py setup
Tear down: python aws_setup.py teardown

All resources are tagged Name=nnclinssoap so teardown can find them cleanly.
"""

import boto3
import os
import sys
import time
import json
import subprocess

# ---------------------------------------------------------------------------
# Configuration — adjust if needed
# ---------------------------------------------------------------------------
REGION         = "us-east-1"
INSTANCE_TYPE  = "r6i.4xlarge"  # 16 vCPU, 128 GB RAM — minimum for process_high (12 CPUs) + Azimuth
KEY_NAME       = "nnclinssoap-key"
KEY_PATH       = os.path.expanduser("~/.ssh/nnclinssoap-key.pem")
SG_NAME        = "nnclinssoap-sg"
INSTANCE_TAG   = "nnclinssoap-pipeline"
DISK_GB        = 100             # Docker images ~15 GB, pipeline work dir ~20 GB
TAG            = [{"Key": "Name", "Value": INSTANCE_TAG}]

# Upstream repo — cloned on boot. No local file transfer needed.
REPO_URL       = "https://github.com/NovoNordisk-OpenSource/nnclinssoap"
REPO_DIR       = "/data/nnclinssoap"

# User-data runs once on first boot as root.
# Installs Docker, Java 21, Nextflow, clones the repo, then signals completion.
USER_DATA = f"""#!/bin/bash
set -eux

# --- system packages ---
dnf update -y
dnf install -y docker git java-21-amazon-corretto

# --- Docker ---
systemctl enable docker
systemctl start docker
usermod -aG docker ec2-user        # lets ec2-user run docker without sudo

# --- Nextflow ---
# cd to /tmp so the installer drops the binary at a known path
cd /tmp && curl -fsSL https://get.nextflow.io | bash
mv /tmp/nextflow /usr/local/bin/
chmod +x /usr/local/bin/nextflow

# --- clone upstream repo (--depth 1 skips full history, much faster) ---
mkdir -p /data
git clone --depth 1 {REPO_URL} {REPO_DIR}
chown -R ec2-user:ec2-user /data

echo "Bootstrap complete" > /tmp/bootstrap_done
"""

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def tag_spec(resource_type):
    return [{"ResourceType": resource_type, "Tags": TAG}]


def get_account_id(session):
    return session.client("sts").get_caller_identity()["Account"]


def get_default_vpc(ec2):
    vpcs = ec2.describe_vpcs(Filters=[{"Name": "isDefault", "Values": ["true"]}])["Vpcs"]
    if not vpcs:
        raise RuntimeError("No default VPC found — create one in the AWS console first.")
    return vpcs[0]["VpcId"]


def get_default_subnet(ec2, vpc_id):
    subnets = ec2.describe_subnets(
        Filters=[{"Name": "vpc-id", "Values": [vpc_id]},
                 {"Name": "defaultForAz", "Values": ["true"]}]
    )["Subnets"]
    if not subnets:
        raise RuntimeError("No default subnet found in VPC.")
    # Pick the first AZ — any will work
    return subnets[0]["SubnetId"]


def get_latest_al2023_ami(ec2):
    images = ec2.describe_images(
        Owners=["amazon"],
        Filters=[{"Name": "name",  "Values": ["al2023-ami-2023*-x86_64"]},
                 {"Name": "state", "Values": ["available"]}]
    )["Images"]
    return sorted(images, key=lambda x: x["CreationDate"])[-1]["ImageId"]


def find_instance(ec2):
    """Return the first running/stopped nnclinssoap instance, or None."""
    resp = ec2.describe_instances(
        Filters=[{"Name": "tag:Name",          "Values": [INSTANCE_TAG]},
                 {"Name": "instance-state-name", "Values": ["pending", "running", "stopped"]}]
    )
    for r in resp["Reservations"]:
        for i in r["Instances"]:
            return i
    return None


def find_sg(ec2):
    sgs = ec2.describe_security_groups(
        Filters=[{"Name": "group-name", "Values": [SG_NAME]}]
    )["SecurityGroups"]
    return sgs[0]["GroupId"] if sgs else None


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

def setup():
    session = boto3.Session(region_name=REGION)
    ec2     = session.client("ec2")

    account_id = get_account_id(session)
    print(f"Account : {account_id}")
    print(f"Region  : {REGION}")

    # --- Step 1: Default VPC + subnet ---
    vpc_id    = get_default_vpc(ec2)
    subnet_id = get_default_subnet(ec2, vpc_id)
    print(f"\n[1/6] VPC      : {vpc_id}")
    print(f"      Subnet   : {subnet_id}")

    # --- Step 2: Latest AL2023 AMI ---
    ami_id = get_latest_al2023_ami(ec2)
    print(f"\n[2/6] AMI      : {ami_id}  (Amazon Linux 2023)")

    # --- Step 3: SSH key pair ---
    if os.path.exists(KEY_PATH):
        print(f"\n[3/6] Key pair : already exists at {KEY_PATH} — skipping creation")
    else:
        try:
            resp = ec2.create_key_pair(KeyName=KEY_NAME, TagSpecifications=tag_spec("key-pair"))
            with open(KEY_PATH, "w") as f:
                f.write(resp["KeyMaterial"])
            os.chmod(KEY_PATH, 0o600)
            print(f"\n[3/6] Key pair : created  →  {KEY_PATH}")
        except ec2.exceptions.ClientError as e:
            if "InvalidKeyPair.Duplicate" in str(e):
                print(f"\n[3/6] Key pair : '{KEY_NAME}' already exists in AWS but .pem not found locally.")
                print("      Delete it in the EC2 console and re-run, or place the existing .pem at:")
                print(f"      {KEY_PATH}")
                sys.exit(1)
            raise

    # --- Step 4: Security group (SSH inbound only) ---
    sg_id = find_sg(ec2)
    if sg_id:
        print(f"\n[4/6] Sec group: {sg_id}  (already exists — skipping)")
    else:
        sg    = ec2.create_security_group(GroupName=SG_NAME,
                                          Description="nnclinssoap pipeline SSH access",
                                          VpcId=vpc_id,
                                          TagSpecifications=tag_spec("security-group"))
        sg_id = sg["GroupId"]
        ec2.authorize_security_group_ingress(
            GroupId=sg_id,
            IpPermissions=[{"IpProtocol": "tcp", "FromPort": 22, "ToPort": 22,
                             "IpRanges": [{"CidrIp": "0.0.0.0/0",
                                           "Description": "SSH"}]}]
        )
        print(f"\n[4/6] Sec group: {sg_id}  (created, SSH/22 open)")

    # --- Step 5: Launch On-Demand instance ---
    existing = find_instance(ec2)
    if existing:
        instance_id = existing["InstanceId"]
        print(f"\n[5/6] Instance : {instance_id}  (already exists — skipping launch)")
    else:
        resp = ec2.run_instances(
            ImageId=ami_id,
            InstanceType=INSTANCE_TYPE,
            KeyName=KEY_NAME,
            SecurityGroupIds=[sg_id],
            SubnetId=subnet_id,
            MinCount=1, MaxCount=1,
            UserData=USER_DATA,
            # On-Demand — Spot blocked on this account (InvalidParameterCombination)
            # 100 GB gp3 root volume
            BlockDeviceMappings=[{
                "DeviceName": "/dev/xvda",
                "Ebs": {"VolumeSize": DISK_GB, "VolumeType": "gp3",
                        "DeleteOnTermination": True}
            }],
            TagSpecifications=tag_spec("instance")
        )
        instance_id = resp["Instances"][0]["InstanceId"]
        print(f"\n[5/6] Instance : {instance_id}  (On-Demand {INSTANCE_TYPE}, launching...)")

    # --- Step 6: Wait for running + print SSH command ---
    print(f"\n[6/6] Waiting for instance to enter 'running' state...")
    waiter = ec2.get_waiter("instance_running")
    waiter.wait(InstanceIds=[instance_id],
                WaiterConfig={"Delay": 10, "MaxAttempts": 36})

    desc       = ec2.describe_instances(InstanceIds=[instance_id])
    public_ip  = desc["Reservations"][0]["Instances"][0].get("PublicIpAddress", "N/A")

    print(f"\n{'='*60}")
    print(f"  Instance running!")
    print(f"  ID        : {instance_id}")
    print(f"  Public IP : {public_ip}")
    print(f"{'='*60}")
    print(f"\nNext steps:")
    print(f"\n  1. SSH in (bootstrap takes ~3 min — repo is cloned automatically):")
    print(f"     ssh -i {KEY_PATH} ec2-user@{public_ip}")
    print(f"\n  2. Watch bootstrap live (Ctrl+C when done, takes ~3-5 min):")
    print(f"     sudo tail -f /var/log/cloud-init-output.log")
    print(f"     # Success: last line will be 'Bootstrap complete'")
    print(f"     # Failure: the log shows which command failed and why")
    print(f"\n  3. Build Docker images — time is recorded for benchmarking:")
    print(f"     cd {REPO_DIR}/docker && time ./build_all_images.sh 2>&1 | tee /tmp/build.log")
    print(f"     # build time will be printed at the end; full log at /tmp/build.log")
    print(f"\n  4. Run the upstream pipeline:")
    print(f"     cd {REPO_DIR}/SpatialXenium")
    print(f"     nextflow run main.nf -profile docker \\")
    print(f'       -c <(printf \'executor.cpus = 16\\nexecutor.memory = "120 GB"\\nprocess {{ withLabel:process_high {{ cpus = 12 }} }}\') \\')
    print(f"       --input samplesheet.csv \\")
    print(f"       --outdir results")
    print(f"\n  IMPORTANT: terminate the instance when done to stop charges:")
    print(f"     python aws_setup.py teardown")

    # Save state for teardown
    state = {"instance_id": instance_id, "sg_id": sg_id, "public_ip": public_ip}
    with open("aws_state.json", "w") as f:
        json.dump(state, f, indent=2)
    print(f"\n  State saved to aws_state.json")


# ---------------------------------------------------------------------------
# Teardown
# ---------------------------------------------------------------------------

def teardown():
    session = boto3.Session(region_name=REGION)
    ec2     = session.client("ec2")

    # Load saved state if available
    state = {}
    if os.path.exists("aws_state.json"):
        with open("aws_state.json") as f:
            state = json.load(f)

    # --- Terminate instance ---
    instance = find_instance(ec2)
    if instance:
        instance_id = instance["InstanceId"]
        ec2.terminate_instances(InstanceIds=[instance_id])
        print(f"Terminating instance {instance_id}...")
        waiter = ec2.get_waiter("instance_terminated")
        waiter.wait(InstanceIds=[instance_id], WaiterConfig={"Delay": 10, "MaxAttempts": 36})
        print(f"Instance {instance_id} terminated.")
    else:
        print("No running instance found — skipping.")

    # --- Delete security group (must wait for instance to be gone first) ---
    sg_id = state.get("sg_id") or find_sg(ec2)
    if sg_id:
        try:
            ec2.delete_security_group(GroupId=sg_id)
            print(f"Security group {sg_id} deleted.")
        except Exception as e:
            print(f"Could not delete security group (may still have dependencies): {e}")
    else:
        print("No security group found — skipping.")

    # --- Delete key pair from AWS (local .pem kept for safety) ---
    try:
        ec2.delete_key_pair(KeyName=KEY_NAME)
        print(f"Key pair '{KEY_NAME}' deleted from AWS.")
        print(f"Local key kept at {KEY_PATH} — delete manually if not needed.")
    except Exception as e:
        print(f"Could not delete key pair: {e}")

    # Clean up state file
    if os.path.exists("aws_state.json"):
        os.remove("aws_state.json")

    print("\nTeardown complete. All billable resources removed.")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    if len(sys.argv) != 2 or sys.argv[1] not in ("setup", "teardown"):
        print("Usage: python aws_setup.py setup|teardown")
        sys.exit(1)

    if sys.argv[1] == "setup":
        setup()
    else:
        confirm = input("This will TERMINATE the EC2 instance and delete all AWS resources. Type 'yes' to confirm: ")
        if confirm.strip().lower() == "yes":
            teardown()
        else:
            print("Aborted.")
