#ifndef FILTFILT_FIXED_H
#define FILTFILT_FIXED_H

#include <stddef.h>

#define NFILT 5
#define NFACT 4
#define NSAMPLES 68

void filter_iir_fixed(const double *x, double *y, size_t n, const double zi[NFACT]);
void reverse_inplace(double *x, size_t n);
void filtfilt_fixed_68(const double in[NSAMPLES], double out[NSAMPLES]);

double max_abs_error(const double *a, const double *b, size_t n);

#endif
