# Estimate relationship between severity and percentage economic losses
import numpy as np
import pandas as pd
import yaml
from sklearn.linear_model import LinearRegression

# Clean up if you later fit more models
if __name__ == "__main__":
    econ_loss_raw = pd.read_excel("data/raw/Economic damages source review.xlsx", sheet_name="Updated numbers")

    econ_loss = econ_loss_raw.rename(columns={'Fraction GDP losses': 'pct_gdp_loss',
                                            'Mortality (SMU)': 'mortality_smu'})
    econ_loss[['pct_gdp_loss']] = econ_loss[['pct_gdp_loss']] * 100
    econ_loss = econ_loss[['pct_gdp_loss', 'mortality_smu']]

    econ_loss_clean = econ_loss.dropna(axis=0)

    # Fit regression
    model = LinearRegression()
    model.fit(np.log(econ_loss_clean[['mortality_smu']]),
              np.log(econ_loss_clean['pct_gdp_loss']))

    results = {'intercept': model.intercept_,
            'coef': model.coef_[0]}
    
    print(f"""Economic model parameter estimates\n
              Intercept: {results['intercept']}\n
              Coefficient {results['coef']}""")

    with open("output/econ_loss_models/default_model.yaml", "w") as f:
        yaml.dump(results, f)
