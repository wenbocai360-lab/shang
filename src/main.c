#include "filtfilt_fixed.h"

#include <stdio.h>

int main(void) {
    double in[NSAMPLES] = {0};
    double out[NSAMPLES] = {0};

    for (int i = 0; i < NSAMPLES; ++i) {
        in[i] = (double)i;
    }

    filtfilt_fixed_68(in, out);

    for (int i = 0; i < NSAMPLES; ++i) {
        printf("%d,%.15f\n", i, out[i]);
    }

    return 0;
}
