/*
 * Shared DMAS-CF math for the CPU MEX (calculateDMASCFMex.cpp) and the CUDA kernel
 * (calculateDMASCFKernel.cu), so both use exactly the same formulas.
 *
 * Order n DMAS is the n-th elementary symmetric polynomial of the signed n-th roots
 * s = sgn(x)*|x|^(1/n) of the delayed signals x (Jansen et al., IEEE Access 2026,
 * Eq. 4-6), computed from the power sums P_k = sum(s^k) with the Newton-Girard
 * identities (Eq. 9-12).
 *
 * The highest power sum needs no roots: s^n = x for odd n and s^n = |x| for even n,
 * so P_n = sum(x) for odd n and P_n = sum(|x|) for even n.
 *
 * By Cosys-Lab, University of Antwerp
 * Contributors: Wouter Jansen, Jan Steckel
 */
#ifndef CALCULATE_DMASCF_CORE_H
#define CALCULATE_DMASCF_CORE_H

#ifdef __CUDACC__
#define DMASCF_HOST_DEVICE __host__ __device__ __forceinline__
#define DMASCF_ABS(v) fabs(v)
#else
#include <cmath>
#define DMASCF_HOST_DEVICE inline
#define DMASCF_ABS(v) std::fabs(v)
#endif

/*
 * Running sums over the microphones for one output pixel (t, psi).
 * Only the sums needed for ORDER and CF are updated; the others stay zero.
 */
template <typename T>
struct DmasSums {
    T sumX;     /* sum(x), DAS (Eq. 2), P_3 and P_5, CF numerator (Eq. 13) */
    T sumAbsX;  /* sum(|x|), P_2 for order 2 and P_4 for order 4 */
    T sumX2;    /* sum(x^2), CF denominator (Eq. 13) */
    T P1;       /* sum(s) */
    T P2;       /* sum(s^2), orders 3-5 */
    T P3;       /* sum(s^3), orders 4-5 */
    T P4;       /* sum(s^4), order 5 */
};

template <typename T>
DMASCF_HOST_DEVICE void dmasResetSums(DmasSums<T> &sums) {
    sums.sumX = T(0); sums.sumAbsX = T(0); sums.sumX2 = T(0);
    sums.P1 = T(0); sums.P2 = T(0); sums.P3 = T(0); sums.P4 = T(0);
}

/* Add one microphone: x is the delayed sample, s its signed ORDER-th root. */
template <int ORDER, bool CF, typename T>
DMASCF_HOST_DEVICE void dmasAccumulate(DmasSums<T> &sums, T x, T s) {
    sums.sumX += x;
    if (CF) sums.sumX2 += x * x;
    if (ORDER == 2 || ORDER == 4) sums.sumAbsX += DMASCF_ABS(x); /* branch-free, x has random sign */
    if (ORDER >= 2) {
        T s2 = s * s;
        sums.P1 += s;
        if (ORDER >= 3) sums.P2 += s2;
        if (ORDER >= 4) sums.P3 += s2 * s;
        if (ORDER >= 5) sums.P4 += s2 * s2;
    }
}

/* Absolute DMAS-CF output of one pixel from its sums (Eq. 2, 9-14). */
template <int ORDER, bool CF, typename T>
DMASCF_HOST_DEVICE T dmasOutput(const DmasSums<T> &sums, int nMicrophones) {
    const T P1 = sums.P1;
    const T P1sq = P1 * P1;
    T out;
    switch (ORDER) {
        case 2: /* Eq. 9, P_2 = sum(|x|) */
            out = T(0.5) * (P1sq - sums.sumAbsX);
            break;
        case 3: /* Eq. 10, P_3 = sum(x) */
            out = (P1sq * P1 + T(2) * sums.sumX - T(3) * P1 * sums.P2) / T(6);
            break;
        case 4: /* Eq. 11, P_4 = sum(|x|) */
            out = (P1sq * P1sq - T(6) * sums.sumAbsX + T(3) * sums.P2 * sums.P2
                   - T(6) * sums.P2 * P1sq + T(8) * sums.P3 * P1) / T(24);
            break;
        case 5: /* Eq. 12, P_5 = sum(x) */
            out = (P1sq * P1sq * P1 - T(10) * sums.P2 * P1sq * P1 + T(15) * sums.P2 * sums.P2 * P1
                   + T(20) * sums.P3 * P1sq - T(20) * sums.P3 * sums.P2 - T(30) * P1 * sums.P4
                   + T(24) * sums.sumX) / T(120);
            break;
        default: /* Eq. 2, DAS */
            out = sums.sumX;
            break;
    }
    if (CF) { /* Eq. 13-14 */
        out *= (sums.sumX * sums.sumX) / (T(nMicrophones) * sums.sumX2 + T(1e-6));
    }
    return DMASCF_ABS(out);
}

#endif
