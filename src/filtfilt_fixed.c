#include "filtfilt_fixed.h"

#include <math.h>
#include <string.h>

static const double A[NFILT] = {
    1.0,
    -2.369513007182036,
    2.313988414415877,
    -1.054665405878565,
    0.187379492368184,
};

static const double B[NFILT] = {
    0.004824343357716,
    0.019297373430865,
    0.028946060146297,
    0.019297373430865,
    0.004824343357716,
};

static const double ZI0[NFACT] = {
    0.9951756566422711,
    -1.3936347239705993,
    0.8914076302989508,
    -0.1825551490104656,
};

void filter_iir_fixed(const double *x, double *y, size_t n, const double zi[NFACT]) {
    double z[NFACT];
    memcpy(z, zi, sizeof(z));

    for (size_t i = 0; i < n; ++i) {
        double x0 = x[i];
        double y0 = B[0] * x0 + z[0];

        z[0] = B[1] * x0 + z[1] - A[1] * y0;
        z[1] = B[2] * x0 + z[2] - A[2] * y0;
        z[2] = B[3] * x0 + z[3] - A[3] * y0;
        z[3] = B[4] * x0 - A[4] * y0;

        y[i] = y0;
    }
}

void reverse_inplace(double *x, size_t n) {
    for (size_t i = 0; i < n / 2; ++i) {
        double t = x[i];
        x[i] = x[n - 1 - i];
        x[n - 1 - i] = t;
    }
}

void filtfilt_fixed_68(const double in[NSAMPLES], double out[NSAMPLES]) {
    double tmp[NSAMPLES];

    filter_iir_fixed(in, tmp, NSAMPLES, ZI0);
    reverse_inplace(tmp, NSAMPLES);
    filter_iir_fixed(tmp, out, NSAMPLES, ZI0);
    reverse_inplace(out, NSAMPLES);
}

double max_abs_error(const double *a, const double *b, size_t n) {
    double m = 0.0;
    for (size_t i = 0; i < n; ++i) {
        double e = fabs(a[i] - b[i]);
        if (e > m) {
            m = e;
        }
    }
    return m;
}
