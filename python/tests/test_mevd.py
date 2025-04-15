import unittest
import numpy as np

from pandemic_model.stats.mevd import MEVD


class TestMEVD(unittest.TestCase):
    def setUp(self):
        arrival_counts = [10, 11, 12, 20, 21, 30, 31, 32, 33]
        self.params = {'shape': 0.3, 'loc': 0, 'scale': 1}
        self.mevd = MEVD(
            arrival_counts,
            dist_type='genpareto',
            dist_params=self.params
        )
        self.x_vals = np.linspace(self.params['loc'], 1e6, 100)

    def test_cdf_range(self):
        cdf_vals = self.mevd.cdf(self.x_vals)
        self.assertTrue(np.all((cdf_vals >= 0) & (cdf_vals <= 1)))

    def test_sf_cdf_relationship(self):
        cdf_vals, sf_vals = self.mevd.cdf(self.x_vals), self.mevd.sf(self.x_vals)
        np.testing.assert_allclose(cdf_vals + sf_vals, np.ones_like(self.x_vals), rtol=1e-5)

    def test_pdf_positivity(self):
        self.assertTrue(np.all(self.mevd.pdf(self.x_vals) >= 0))

    def test_cdf_monotonicity(self):
        self.assertTrue(np.all(np.diff(self.mevd.cdf(self.x_vals)) >= -1e-6))

    def test_ppf_inverse(self):
        x_test = np.linspace(self.params['loc'] + 0.1, 15, 10)
        np.testing.assert_allclose(self.mevd.ppf(self.mevd.cdf(x_test)), x_test, rtol=1e-3)

    def test_ppf_scalar_vs_array(self):
        q_scalar, q_array = 0.5, np.array([0.5])
        np.testing.assert_allclose(self.mevd.ppf(q_scalar), self.mevd.ppf(q_array)[0], rtol=1e-6)

    def test_gpd_equivalence(self):
        """Test that an MEVD with one observation per window is equal to the base distribution."""
        n_samples = 100
        arrival_counts = np.repeat(1, n_samples)
        mevd = MEVD(arrival_counts, dist_type='genpareto', dist_params=self.params)
        x_vals = np.linspace(self.params['loc'], 1e6, 100)
        base_cdf = mevd.frozen_dist
        np.testing.assert_allclose(mevd.cdf(x_vals), base_cdf.cdf(x_vals), rtol=1e-3)

if __name__ == "__main__":
    unittest.main()