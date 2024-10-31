import pandas as pd
import numpy as np
import argparse


def extract_positive_cases(filepath):
    """This script extracts only the positive cases - i.e. the offspring """
    df = pd.read_csv(filepath, sep=" ")
    df.columns = ["FID", "ID", "Father", "Mother", "Sex", "Phenotype"]
    print(df)

extract_positive_cases("Xchr/data/FAM1_2024Oct14.fam")