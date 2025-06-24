import numpy as np
from scipy.optimize import approx_fprime

def grad(f, x, eps=1e-4):
    """Numerical gradient approximation."""
    return approx_fprime(x, f, eps)

def hess(f, x, eps=1e-4):
    """Numerical Hessian approximation."""
    n = len(x)
    H = np.empty((n, n), float)
    ei = np.zeros(n)

    # central differences for second partials
    for i in range(n):
        ei[i] = eps
        for j in range(i, n):
            ej = np.zeros_like(ei)
            ej[j] = eps
            
            H[i, j] = (
                f(x + ei + ej) - f(x + ei - ej)
              - f(x - ei + ej) + f(x - ei - ej)
            ) / (4 * eps * eps)
            H[j, i] = H[i, j]
        ei[i] = 0.0

    # tiny asymmetry/round-off
    return H
