# ============================================================
# Home Credit Feature Engineering Script
# ============================================================
# This script creates production-ready features based on
# EDA findings for predicting loan default.
#
# The functions are designed to apply identical transformations
# to both training and test data, ensuring reproducibility
# and preventing data leakage (CRISP-DM: Data Preparation).
#
# USAGE:
# source("feature_engineering.R")
#
# train_features <- engineer_features(train_df, supplementary_data, fit = TRUE)
# test_features  <- engineer_features(test_df, supplementary_data, fit = FALSE)
# ============================================================

library(tidyverse)

# ============================================================
# Global storage for training statistics
# These values are learned from training data only
# and reused for test data to prevent leakage
# ============================================================

ext_source_medians <- list()

# ============================================================
# ASSIGNMENT: Clean and transform application data
# Fix DAYS_EMPLOYED = 365243 anomaly (EDA finding)
# ============================================================

fix_days_employed <- function(df) {
  df %>%
    mutate(
      DAYS_EMPLOYED = ifelse(DAYS_EMPLOYED == 365243,
                             NA,
                             DAYS_EMPLOYED)
    )
}

# ============================================================
# ASSIGNMENT: Create engineered demographic features
# - Update age and employment duration
# - Convert negative day-based variables into years
# ============================================================

add_demographic_features <- function(df) {
  df %>%
    mutate(
      AGE_YEARS = -DAYS_BIRTH / 365.25,
      EMPLOYMENT_YEARS = -DAYS_EMPLOYED / 365.25
    )
}

# ============================================================
# ASSIGNMENT: Handle missing EXT_SOURCE variables
# - Compute medians using training data only
# ============================================================

fit_ext_source_medians <- function(df) {
  ext_source_medians <<- list(
    EXT_SOURCE_1 = median(df$EXT_SOURCE_1, na.rm = TRUE),
    EXT_SOURCE_2 = median(df$EXT_SOURCE_2, na.rm = TRUE),
    EXT_SOURCE_3 = median(df$EXT_SOURCE_3, na.rm = TRUE)
  )
}

# ============================================================
# ASSIGNMENT: Apply identical transformations to train and test
# - Reuse training-derived medians
# ============================================================

apply_ext_source_imputation <- function(df) {
  df %>%
    mutate(
      EXT_SOURCE_1 = ifelse(is.na(EXT_SOURCE_1),
                            ext_source_medians$EXT_SOURCE_1,
                            EXT_SOURCE_1),
      EXT_SOURCE_2 = ifelse(is.na(EXT_SOURCE_2),
                            ext_source_medians$EXT_SOURCE_2,
                            EXT_SOURCE_2),
      EXT_SOURCE_3 = ifelse(is.na(EXT_SOURCE_3),
                            ext_source_medians$EXT_SOURCE_3,
                            EXT_SOURCE_3)
    )
}

# ============================================================
# ASSIGNMENT: Add missing data indicators
# - Missingness often predictive (credit risk best practice)
# ============================================================

add_missing_indicators <- function(df) {
  df %>%
    mutate(
      EXT_SOURCE_1_MISSING = ifelse(is.na(EXT_SOURCE_1), 1, 0),
      EXT_SOURCE_2_MISSING = ifelse(is.na(EXT_SOURCE_2), 1, 0),
      EXT_SOURCE_3_MISSING = ifelse(is.na(EXT_SOURCE_3), 1, 0)
    )
}

# ============================================================
# ASSIGNMENT: Address other EDA-identified issues
# - Missing employment duration found to be informative
# ============================================================

add_employment_missing_indicator <- function(df) {
  df %>%
    mutate(
      EMPLOYMENT_MISSING = ifelse(is.na(DAYS_EMPLOYED), 1, 0)
    )
}


# ============================================================
# ASSIGNMENT: Add financial ratios
# - Credit-to-income
# - Loan-to-value proxy
# - Other affordability ratios
# ============================================================

add_financial_ratios <- function(df) {
  df %>%
    mutate(
      CREDIT_INCOME_RATIO  = AMT_CREDIT / AMT_INCOME_TOTAL,
      ANNUITY_INCOME_RATIO = AMT_ANNUITY / AMT_INCOME_TOTAL,
      CREDIT_GOODS_RATIO   = AMT_CREDIT / AMT_GOODS_PRICE
    )
}

# ============================================================
# ASSIGNMENT: Aggregate supplementary data to applicant level
# bureau.csv
# - Count of prior credits
# - Active vs closed
# - Overdue amounts
# ============================================================

# ============================================================
# ASSIGNMENT: Aggregate bureau.csv to applicant level
# - Count of prior credits
# - Active vs closed credits
# - Overdue amounts
# - Debt ratios
# ============================================================

aggregate_bureau <- function(bureau_df) {
  bureau_df %>%
    group_by(SK_ID_CURR) %>%
    summarise(
      BUREAU_LOAN_COUNT   = n(),
      BUREAU_ACTIVE_COUNT = sum(CREDIT_ACTIVE == "Active", na.rm = TRUE),
      BUREAU_OVERDUE_SUM  = sum(AMT_CREDIT_SUM_OVERDUE, na.rm = TRUE),

      # Debt ratio: total debt relative to total credit
      BUREAU_DEBT_RATIO = sum(AMT_CREDIT_SUM_DEBT, na.rm = TRUE) /
                          sum(AMT_CREDIT_SUM, na.rm = TRUE),

      .groups = "drop"
    )
}


# ============================================================
# ASSIGNMENT: Aggregate previous_application.csv
# - Count of applications
# - Approval rate
# - Refusal history
# ============================================================

aggregate_previous_applications <- function(prev_df) {
  prev_df %>%
    group_by(SK_ID_CURR) %>%
    summarise(
      PREV_APP_COUNT      = n(),
      PREV_APPROVAL_RATE  = mean(NAME_CONTRACT_STATUS == "Approved", na.rm = TRUE),
      PREV_REFUSAL_RATE   = mean(NAME_CONTRACT_STATUS == "Refused", na.rm = TRUE),
      .groups = "drop"
    )
}
# ============================================================
# ASSIGNMENT: Aggregate installments_payments.csv
# - Late payment percentages
# - Payment behavior trends
# ============================================================

# ============================================================
# ASSIGNMENT: Aggregate installments_payments.csv
# - Late payment percentages
# - Payment behavior trends
# ============================================================

aggregate_installments <- function(inst_df) {
  inst_df %>%
    mutate(
      PAYMENT_DELAY = DAYS_ENTRY_PAYMENT - DAYS_INSTALMENT,
      LATE_PAYMENT  = PAYMENT_DELAY > 0
    ) %>%
    group_by(SK_ID_CURR) %>%
    summarise(
      LATE_PAYMENT_RATE = mean(LATE_PAYMENT, na.rm = TRUE),
      AVG_PAYMENT_DELAY = mean(PAYMENT_DELAY, na.rm = TRUE),
      INSTALLMENT_COUNT = n(),
      .groups = "drop"
    )
}

engineer_features <- function(df, supplementary_data, fit = TRUE) {

  # ASSIGNMENT: Compute statistics from training data only
  if (fit) {
    fit_ext_source_medians(df)
  }

  df %>%
    fix_days_employed() %>%
    add_demographic_features() %>%
    apply_ext_source_imputation() %>%
    add_missing_indicators() %>%
    add_employment_missing_indicator() %>%   # NEW
    add_financial_ratios() %>%
    add_binned_features() %>%                # NEW
    left_join(supplementary_data$bureau, by = "SK_ID_CURR") %>%
    left_join(supplementary_data$previous, by = "SK_ID_CURR") %>%
    left_join(supplementary_data$installments, by = "SK_ID_CURR")
}


# ============================================================
# ASSIGNMENT: Add binned variables
# - Capture non-linear age effects
# ============================================================

add_binned_features <- function(df) {
  df %>%
    mutate(
      AGE_BIN = cut(
        AGE_YEARS,
        breaks = c(18, 30, 40, 50, 60, 100),
        include.lowest = TRUE
      )
    )
}
