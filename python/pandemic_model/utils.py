"""Project-wide Python utilities."""

viral_family_map = {
    'cchf': 'nairoviridae',
    'crimean_congo_haemorrhagic_fever': 'nairoviridae',
    'rift_valley_fever': 'phenuiviridae',
    'mers': 'coronaviridae',
    'ebola': 'filoviridae',
    'zika': 'flaviviridae',
    'nipah': 'paramyxoviridae',
    'flu': 'orthomyxoviridae',
    'chikungunya': 'togaviridae',
    'lassa': 'arenaviridae',
    'covid-19': 'coronaviridae'
}

pathogen_group_map = {
    'cchf': 'crimean_congo_hemorrhagic_fever',
    'crimean_congo_haemorrhagic_fever': 'crimean_congo_hemorrhagic_fever',
    'rift_valley_fever': 'rift_valley_fever',
    'flu': 'flu',
    'mers': 'coronavirus',
    'ebola': 'ebola',
    'zika': 'zika',
    'nipah': 'nipah',
    'chikungunya': 'chikungunya',
    'lassa': 'lassa',
    'covid-19': 'coronavirus'
}


def get_measure_units(measure: str) -> str:
    "Get units associated with intensity or severity measure."
    if measure == 'intensity':
        return "Deaths per 10,000 per year"
    elif measure == 'severity':
        return "Deaths per 10,000"
    else:
        raise ValueError(f"Measure must be either 'intensity' or 'severity'. '{measure}' was passed.")
