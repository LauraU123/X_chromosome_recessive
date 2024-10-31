import pandas as pd
import numpy as np
import argparse


def save_to_csv(data, outputfile):
    """Saving dictionary to csv"""
    df_output = pd.DataFrame.from_dict(data, orient='index')
    print(df_output)
    df_output.to_csv(outputfile, header=False)
    print(f"Output written to {outputfile}.")

def extract_positive_cases(filepath):
    """This script extracts only the positive cases - i.e. the offspring """
    df = pd.read_csv(filepath, sep=" ", header=None)
    df.columns = ["FID", "ID", "Father", "Mother", "Sex", "Phenotype"]
    # 2 is the positive phenotype
    positive = df.loc[df['Phenotype'] == 2, 'ID']
    positive_cases = []
    # convert to list
    for i in positive: positive_cases.append(i)

    return positive_cases

def markers(positive_cases, filepath, outputfile):
    """Finding markers that correspond to the relevant"""
    recode = {
        "2 2": "B", "1 1": "A", "1 2": "N", "2 1": "N", "0 0": "N",
        "A A": "A", "B B": "B", "A B": "N", "B A": "N"
    }
    dictionary = {}
    with open(filepath) as f:
        for line in f:
            parts = line.split("\t")
            if parts[1] in positive_cases:
                dictionary[f"{parts[1]}"] = [recode.get(marker.strip(), None) for marker in parts[6:]] 
    save_to_csv(dictionary, outputfile)
    #return dictionary


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description="Find paternal haplotypes from input data",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    parser.add_argument("--ped", required=True, help="input .ped file")
    parser.add_argument("--fam", required=True, help="input .fam file")
    parser.add_argument("--output", required=False, help=".csv file")
    args = parser.parse_args()
    
    positive_cases = extract_positive_cases(args.fam)
    markers(positive_cases, args.ped, args.output)


#extract_positive_cases("Xchr/data/FAM1_2024Oct14.fam")