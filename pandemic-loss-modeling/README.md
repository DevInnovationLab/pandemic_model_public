# pandemic-loss-modeling
This repo contains the dataset and tools for forecasting pandemic losses, based on historical epidemic severities from Marani et al. (2021). 

<br/>

### Epidemic Dataset (1500–2024): `epidemics_240816.xlsx`
This updated dataset from Marani et al. (2021) provides information on historical epidemics, including start and end years, location, mortality and details of specific diseases involved.

**Notes:**
- **Unknown Death Count**: Coded as `-999` in the `death_thousand` field.
- **Negligible Death Count**: Coded as `0` in the `death_thousand` field.
- **Population Data**: The population at the start year of each epidemic is provided in `pop_thousand`.

**Severity Calculations:**
- **Deaths per Thousand**: `severity_perthousand` = (`death_thousand` / `pop_thousand`) * 1,000
- **Deaths per 10,000 (SMU)**: `severity_smu` = `severity_perthousand` * 10

<br/>
