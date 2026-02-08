# MSBA-Capstone-Home-Credit

## Project Overview
This repository contains the data preparation workflow for the Home Credit Default Risk capstone project. The goal is to translate insights from exploratory data analysis (EDA) into reusable, production-ready feature engineering code that applies consistent transformations to both training and test data while preventing data leakage.

The work aligns with the CRISP-DM Data Preparation phase, emphasizing reproducibility, modular design, and clean handoff to modeling.

## Objectives
- Translate EDA findings into reusable cleaning and feature engineering functions
- Ensure identical transformations for training and test data (no data leakage)
- Document the data preparation pipeline clearly and professionally

## Data Preparation Script
The primary deliverable is `data_preparation.R`, which provides modular functions for cleaning and feature engineering. It covers the following components:

### Data cleaning
- Fixes the `DAYS_EMPLOYED = 365243` placeholder anomaly
- Handles missing values in `EXT_SOURCE_1`, `EXT_SOURCE_2`, and `EXT_SOURCE_3` using medians computed from training data only

### Demographic features
Converts `DAYS_BIRTH` and `DAYS_EMPLOYED` into interpretable features:

- `AGE_YEARS`
- `EMPLOYMENT_YEARS`

### Missing data indicators
- Adds binary flags for missing `EXT_SOURCE` variables
- Adds an indicator for missing employment history

### Financial ratios
- Credit-to-income ratio
- Annuity-to-income ratio
- Credit-to-goods price ratio

### Binned / non-linear features
- Age bins to capture non-linear effects in default risk

### Supplementary data aggregation
**`bureau.csv`**
- Count of prior credits
- Active credit count
- Overdue credit amounts
- Debt-to-credit ratio

**`previous_application.csv`**
- Total application count
- Approval rate
- Refusal rate

**`installments_payments.csv`**
- Late payment rate
- Average payment delay
- Installment count

The output of this pipeline is a model-ready dataset at the applicant level.

## Train/Test Consistency (Leakage Prevention)
To prevent data leakage, all statistics used for feature engineering (such as medians for imputing external risk scores) are computed exclusively on the training dataset.

The master function `engineer_features()` uses a `fit` flag:

- `fit = TRUE` learns and stores training-derived statistics
- `fit = FALSE` applies the same stored statistics to test data

This design guarantees identical transformations for both datasets.

## How to Run the Script
The feature engineering script does not load data internally. All datasets are loaded externally and passed into reusable functions.

Example workflow in R:

```r
source("data_preparation.R")

# Build supplementary aggregates
bureau_agg <- aggregate_bureau(bureau_df)
prev_agg   <- aggregate_previous_applications(prev_df)
inst_agg   <- aggregate_installments(inst_df)

supplementary_data <- list(
  bureau = bureau_agg,
  previous = prev_agg,
  installments = inst_agg
)

# Apply feature engineering
train_features <- engineer_features(train_df, supplementary_data, fit = TRUE)
test_features  <- engineer_features(test_df, supplementary_data, fit = FALSE)
```

## Inputs and Outputs
### Input Data
The script expects the following raw datasets:

- `application_train.csv` – Training application data including the `TARGET` variable
- `application_test.csv` – Test application data without the `TARGET` variable
- `bureau.csv` – Credit bureau history for applicants
- `previous_application.csv` – Records of prior loan applications
- `installments_payments.csv` – Historical installment payment behavior

### Output Data
The script produces a model-ready dataset at the applicant level (`SK_ID_CURR`) containing engineered demographic, financial, behavioral, and credit-history features.

- Training output: Includes engineered features and the `TARGET` variable
- Test output: Includes the same engineered features, excluding `TARGET`

Both outputs contain identical feature columns, ensuring consistency for downstream modeling.

## Repository Contents
| File | Description |
| --- | --- |
| `data_preparation.R` | R feature engineering script with reusable, production-ready functions |
| `data_preparation.py` | Python version of the preparation pipeline |
| `eda.qmd` | Exploratory data analysis notebook documenting insights |
| `eda_files/` | Rendered EDA plots and assets |

## Data Source
Home Credit Default Risk dataset (Kaggle).

## Author
Umair Akhtar



