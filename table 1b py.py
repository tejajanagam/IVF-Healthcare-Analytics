import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns

b = pd.read_csv(r"C:\Users\tejaj\OneDrive\Desktop\project 2\Reports and Dashboards Data1b.csv",encoding="latin1")

b.head()

b.tail()

b.shape

b.info()

b.isnull().sum() 

b.duplicated().sum() 

b.describe()
b.describe(include=[np.number])

#striping column names
b.columns = (
    b.columns
    .str.lower()
    .str.strip()
    .str.replace(' ', '_')
    .str.replace('%', 'percent')
    .str.replace('-', '_')
    .str.replace('\n', '')
)

b.columns = (
    b.columns
    .str.replace('(', '', regex=False)
    .str.replace(')', '', regex=False)
    .str.replace('?', '', regex=False)
    .str.replace('/', '_', regex=False)
)

b.columns.tolist()


categorical_cols = b.select_dtypes(include='object').columns

#check unique values
for col in categorical_cols:
    print(f"\n{col}")
    print(b[col].value_counts(dropna=False).head())

#boxplot
b.select_dtypes(include=np.number).boxplot(figsize=(15,6))
plt.xticks(rotation=90)
plt.show()


b_raw = b.copy()

#removing duplicates
b = b.drop_duplicates()


#missing values

b['note'] = b['note'].fillna('No remarks')


fill_zero_cols = [
    'weightkg',
    'apgar',
    'gender0=male_1=female'
]

for col in fill_zero_cols:
    b[col] = b[col].fillna(0)

#typecasting
b['gender0=male=1_female'] = b['gender0=male_1=female'].astype(int)
b['apgar'] = b['apgar'].astype(int)


b['gender_label'] = b['gender0=male_1=female'].map({
    0: 'Male',
    1: 'Female'
})

b['delivery_occurred'] = (b['apgar'] > 0).astype(int)


b.to_csv(
    r"C:\Users\tejaj\OneDrive\Desktop\project 2\Reports_and_Dashboards_Data1b_cleaned.csv",
    index=False,
    encoding="utf-8-sig"
)




#eda
num_cols = b.select_dtypes(include=np.number).columns

eda_summary_b = pd.DataFrame({
    'Mean': b[num_cols].mean(),
    'Median': b[num_cols].median(),
    'Std_Deviation': b[num_cols].std(),
    'Skewness': b[num_cols].skew(),
    'Kurtosis': b[num_cols].kurtosis()
})

eda_summary_b


#boxplot
sns.boxplot(x='group1=chm_2=non_chm', y='weightkg', data=b)
plt.title('Birth Weight by Group (CHM vs Non-CHM)')
plt.show()

sns.countplot(x='apgar', data=b)
plt.title('APGAR Score Distribution')
plt.show()

import pandas as pd
import dtale
df = pd.read_csv(
    r"C:\Users\tejaj\OneDrive\Desktop\project 2\Reports_and_Dashboards_Data1b_cleaned.csv",
    encoding="latin1"
)
d = dtale.show(df)
d.open_browser()




plt.figure(figsize=(8,5))

num_cols = [
    'weightkg',
    'apgar',
    'gender0=male_1=female',
    'delivery_occurred',
    'group1=chm_2=non_chm'
]

corr = b[num_cols].corr()

sns.heatmap(corr, annot=True, cmap='coolwarm', fmt=".2f")
plt.title("Multivariate Correlation Heatmap – Neonatal Outcomes")
plt.show()

















