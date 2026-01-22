#!/usr/bin/env python3
import argparse
from fpdf import FPDF
import os


def parse_arguments():
    """
    Parse command-line arguments.
    """
    parser = argparse.ArgumentParser(description="Generate a PDF report from a list of PNG files.")
    parser.add_argument(
        "--plots", 
        nargs='+',  # Allows space-separated file paths
        required=True, 
        help="Space-separated list of paths to PNG files."
    )
    parser.add_argument(
        "--output", 
        required=True, 
        help="Output PDF file path."
    )
    return parser.parse_args()


def generate_pdf(plots, output_path):
    """
    Create a PDF report containing the provided plots.
    """
    pdf = FPDF()
    pdf.set_auto_page_break(auto=True, margin=15)
    pdf.set_font("Arial", size=12)

    for plot in plots:
        if not os.path.exists(plot):
            print(f"Warning: File not found - {plot}")
            continue
        
        pdf.add_page()
        pdf.cell(0, 10, f"Plot: {os.path.basename(plot)}", ln=True, align="L")
        pdf.image(plot, x=10, y=30, w=190)  # Adjust image dimensions as necessary

    pdf.output(output_path)
    print(f"Report generated successfully: {output_path}")


def main():
    """
    Main function to generate the report.
    """
    args = parse_arguments()
    plots = args.plots

    if not plots:
        print("Error: No valid plots provided.")
        return

    generate_pdf(plots, args.output)


if __name__ == "__main__":
    main()
