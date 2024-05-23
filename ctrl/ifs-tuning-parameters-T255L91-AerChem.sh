# *** IFS tuning (the commented values are EC-Earth 3.2beta and IFS cy36r4)
# *** for resolution T255L91
# Default based on the v16 LPJG vegetation dataset discussed in #449-197 (jcn4)
# The default values are WITH 2nd indirect effect NCLOUDACT=2, NAERCLD=9
# jvg6 is the best alternative configuration found in #449 with NCLOUDACT=0
#                    jvg6     ECE32b     IFS cy36r4
RPRCON=1.34E-3      # 1.52e-4  1.2E-3     1.4E-3
RVICE=0.137         # 0.126    0.13       0.15
RLCRITSNOW=4.0E-5   # 4.2e-5   3.0E-5     5.0E-5
RSNOWLIN2=0.03      # 0.035    0.035      0.025
ENTRORG=1.75E-4     # 1.58e-4  1.5E-4     1.8E-4
DETRPEN=0.75E-4     # 0.75e-4  0.75E-4    0.75E-4
ENTRDD=3.0E-4       # 3.5e-4   3.0E-4     2.0E-4
RMFDEPS=0.3         # 0.27     0.3        0.35
RCLDIFF=3.E-6       # 3.6e-6   3.E-6
RCLDIFFC=5.0        # 5.0
RLCRIT_UPHYS=0.875e-5
