import pandas as pd
import numpy as np
import argparse


def extract_positive_cases(filepath):
    """This script extracts only the positive cases - i.e. the offspring """
    df = pd.read_csv(filepath, sep=" ", header=None)
    df.columns = ["FID", "ID", "Father", "Mother", "Sex", "Phenotype"]
    positive = df.loc[df['Phenotype'] == 2, 'ID']
    output = []
    # convert to list
    for i in positive: output.append(i)
    return output

# get the sequences from the input files and then convert them to the correct format. Then as before.

extract_positive_cases("Xchr/data/FAM1_2024Oct14.fam")