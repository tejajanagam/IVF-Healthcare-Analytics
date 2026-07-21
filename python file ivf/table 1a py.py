import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns

a = pd.read_csv(r"C:\Users\tejaj\OneDrive\Desktop\project 2\Reports and Dashboards Data1a.csv",encoding="latin1")

a.head()

a.tail()

a.shape

a.info()

a.isnull().sum() 

a.duplicated().sum() # 0 duplicated values

a.describe()
a.describe(include=[np.number])

#striping column names
a.columns = (
    a.columns
    .str.lower()
    .str.strip()
    .str.replace(' ', '_')
    .str.replace('%', 'percent')
    .str.replace('-', '_')
    .str.replace('\n', '')
)

a.columns = (
    a.columns
    .str.replace('(', '', regex=False)
    .str.replace(')', '', regex=False)
    .str.replace('/', '_', regex=False)
    .str.replace('=', '_', regex=False)
    .str.replace('?', '', regex=False)
)
a.columns

categorical_cols = a.select_dtypes(include='object').columns

#check unique values
for col in categorical_cols:
    print(f"\n{col}")
    print(a[col].value_counts(dropna=False).head())

#boxplot
a.select_dtypes(include=np.number).boxplot(figsize=(15,6))
plt.xticks(rotation=90)
plt.show()


a_raw = a.copy()

#typecasting 
a['ttnmol_l'] = pd.to_numeric(a['ttnmol_l'], errors='coerce')

#missing value
fill_zero_cols = [
    'miscarriage',
    'live_birth',
    'gaweeks',
    'delivery1_spontaneous_delivery_2_cs_3_conversion_to_cs'
]

for col in fill_zero_cols:
    if col in a.columns:
        a[col] = a[col].fillna(0)



#outlier capping
num_cols = a.select_dtypes(include=np.number).columns

for col in num_cols:
    Q1 = a[col].quantile(0.25)
    Q3 = a[col].quantile(0.75)
    IQR = Q3 - Q1

    lower = Q1 - 1.5 * IQR
    upper = Q3 + 1.5 * IQR

    a[col] = np.where(a[col] < lower, lower,
                       np.where(a[col] > upper, upper, a[col]))


#feature engneering
a['group_label'] = a['group1_chm_2_non_chm'].map({
    1: 'CHM',
    2: 'Non-CHM'
})


a['pregnancy_success'] = (a['clinical_pregnancy'] == 1).astype(int)


a['ttnmol_l'] = a['ttnmol_l'].fillna(a['ttnmol_l'].median())



a.to_csv(
    r"C:\Users\tejaj\OneDrive\Desktop\project 2\Reports_and_Dashboards_Data1a_cleaned.csv",
    index=False,
    encoding="utf-8-sig"
)

#eda

num_cols = a.select_dtypes(include=np.number).columns

eda_summary_a = pd.DataFrame({
    'Mean': a[num_cols].mean(),
    'Median': a[num_cols].median(),
    'Std_Deviation': a[num_cols].std(),
    'Skewness': a[num_cols].skew(),
    'Kurtosis': a[num_cols].kurtosis()
})

eda_summary_a

#boxplot
sns.boxplot(x='pregnancy_success', y='ageyear', data=a)
plt.title('Pregnancy Success vs Age')
plt.show()























