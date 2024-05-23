# namelist.ifs.sh

# Set coupling frequencies for ocean and chemistry coupling
(( ${cpl_freq_atm_oce_sec:-} )) && NFRCO=$(( cpl_freq_atm_oce_sec / ifs_time_step_sec )) || NFRCO=0
(( ${cpl_freq_atm_ctm_hrs:-} )) && NFRCO_CHEM=$(( cpl_freq_atm_ctm_hrs * 3600 / ifs_time_step_sec )) || NFRCO_CHEM=0
(( ${cpl_freq_atm_lpjg_hrs:-} )) && NFRCO_VEG=$(( cpl_freq_atm_lpjg_hrs * 3600 / ifs_time_step_sec )) || NFRCO_VEG=0

# Activate warm ocean parametrisation only in AMIP runs
(( ${cpl_freq_amip_sec:-} )) && LEOCWA=TRUE || LEOCWA=FALSE

# Switch on/off TM5 feedback to IFS, and between CO2-only and full-chemistry TM5 configs 
has_config tm5:o3fb  && LTM5O3=TRUE  || LTM5O3=FALSE
has_config tm5:ch4fb && LTM5CH4=TRUE || LTM5CH4=FALSE
has_config tm5:aerfb && LTM5AER=TRUE || LTM5AER=FALSE
has_config tm5:co2   && LTM5CO2=TRUE || LTM5CO2=FALSE
has_config tm5:co2fb && LTM5CO2FB=TRUE || LTM5CO2FB=FALSE
NLEV_TM5=${tm5_exch_nlevs:-999}

# Switch on/off SPPT and set the ensemble member number (defaults to zero)
has_config sppt && LSPSDT=TRUE || LSPSDT=FALSE
has_config sppt && LFIXSPPT=TRUE || LFIXSPPT=FALSE
NENSFNB=${ifs_ensemble_forecast_number:-0}

# Switch on/off LPJ-GUESS feedback to IFS
(( ${lpjg_on:-}   )) && LLPJGON=TRUE  || LLPJGON=FALSE
(( ${lpjg_fdbck:-}  )) && LLPJGFBON=TRUE || LLPJGFBON=FALSE

# Switch on/off atmospheric nudging
has_config atmnudg && LRLXG=TRUE || LRLXG=FALSE


cat << EOF
&NAMRES
    NFRRES         = 1,
    NRESTS         = -1,-$(( leg_end_sec / 3600 )),
/
&NAERAD
    NRPROMA        = 0,
    LCMIP6         = ${ifs_cmip6},
    SSPNAME        = ${ifs_cmip6_scenario},
    LCOVID19       = ${ifs_covid19},
    COVID19SCEN    = ${ifs_covid19scen},
    LSSP370_LOWCH4 = FALSE,
    CMIP6DATADIR   = "${ini_data_dir}/ifs/cmip6-data/",
    LA4xCO2        = ${ifs_A4xCO2},
    L1PCTCO2       = ${ifs_1PCTCO2},
    LCMIP5         = ${ifs_cmip5},
    CMIP5DATADIR   = "${ini_data_dir}/ifs/cmip5-data",
    NCMIPFIXYR     = ${ifs_cmip_fixyear},
    NCMIPFIXYR_CH4 = ${ifs_cmip_fixyear_ch4},
    NRCP           = ${ifs_cmip5_rcp},
    LHVOLCA        = TRUE,
    LTM5O3         = ${LTM5O3},
    LTM5CH4        = ${LTM5CH4},
    LTM5CO2FB      = ${LTM5CO2FB},
    LTM5AER        = ${LTM5AER},
    LLPJGON        = ${LLPJGON},
    LLPJGFBON      = ${LLPJGFBON},
    LCMIP6_PI_AEROSOLS = ${ifs_cmip6piaer},
    LCMIP6_STRATAER_SIMP = ${lcmip6_strataer_simp},
    LCMIP6_STRATAER_BCKGD = ${lcmip6_strataer_bckgd},
    LCMIP6_STRATAER_FULL = ${lcmip6_strataer_full},
    CCMIP6_STRAT_SIMP  = "${ini_data_dir}/ifs/cmip6-data/CMIP6_1850_2014_total_AOD_masked_troposphere_mean_3.0.0.txt",
    CCMIP6_STRAT_FULL  = "${ini_data_dir}/ifs/cmip6-data/CMIP6_1850_2014_EC_EARTH_aerosol_radiation_2D_3.0.0_L${ifs_res_ver}.nc",
    AEROPIFIL_OPT      = "${ini_data_dir}/ifs/macv2sp-data/tm5_clim_pi_aerosol_opt_v4.0_L${ifs_res_ver}.nc",
    AEROPIFIL_CONC     = "${ini_data_dir}/ifs/macv2sp-data/tm5_clim_pi_aerosol_conc_v4.0_L${ifs_res_ver}.nc",
    LMAC2SP            = ${ifs_mac2sp},
    MAC2SPDIR          = "${ini_data_dir}/ifs/macv2sp-data/",
    LMAC2SPACI         = TRUE,
    L2RAD = TRUE,
    L2RADACCU = TRUE,
    L2RADTEND = FALSE,
    LCLEARSKYDOWN = TRUE
/
&NAEPHY
    LEPHYS         = TRUE,
    LEVDIF         = TRUE,
    LESURF         = TRUE,
    LECOND         = TRUE,
    LECUMF         = TRUE,
    LEPCLD         = TRUE,
    LEEVAP         = TRUE,
    LEVGEN         = TRUE,
    LESSRO         = TRUE,
    LECURR         = FALSE,
    LEGWDG         = TRUE,
    LEGWWMS        = TRUE,
    LEOCWA         = ${LEOCWA},
    LEOZOC         = TRUE,
    LEQNGT         = TRUE,
    LERADI         = TRUE,
    LERADS         = TRUE,
    LESICE         = TRUE,
    LEO3CH         = FALSE,
    LEDCLD         = TRUE,
    LDUCTDIA       = FALSE,
    LWCOU          = FALSE,
    LWCOU2W        = TRUE,
    NSTPW          = 1,
    RDEGREW        = 1.5,
    RSOUTW         = -81.0,
    RNORTW         = 81.0,
    N_COMPUTE_EFF_VEG_FRACTION = $n_compute_eff_veg_fraction
/
&NAMPAR1
    LSPLIT         = TRUE,
    NFLDIN         = 0,
    NFLDOUT        = 50,
    NSTRIN         = 1,
/
&NAMPAR0
    LSTATS         = TRUE,
    LDETAILED_STATS= FALSE,
    LSYNCSTATS     = FALSE,
    LSTATSCPU      = FALSE,
    NPRNT_STATS    = 32,
    LBARRIER_STATS = FALSE,
    LBARRIER_STATS2= FALSE,
    NPROC          = ${ifs_numproc},
EOF

# enforce layout for passing spectral fields to TM
has_config tm5 &&
cat << EOF
    NPRTRW         = ${ifs_numproc},
    NPRTRV         = 1,
EOF

cat << EOF
    NOUTPUT        = 1,
    MP_TYPE        = 2,
    MBX_SIZE       = 128000000,
/
&NAMRLXSM
    LRXSM          = ${ifs_lrxsm},
    LRXSMT1        = ${ifs_lrxsmt1},
    LRXSMT2        = ${ifs_lrxsmt2},
    LRXSMT3        = ${ifs_lrxsmt3},
    LRXSMT4        = ${ifs_lrxsmt4},
    LRXSMS         = ${ifs_lrxsms},
    RLXSMDIR       = "${ini_data_dir}/ifs/ERAILandClim",
/
&NAMDYNCORE
    LAQUA          = FALSE,
/
&NAMDYN
    TSTEP          = ${ifs_time_step_sec}.0,
    LMASCOR        = TRUE,
    LMASDRY        = TRUE,
/
&NAMNMI
    LASSI          = FALSE,
/
&NAMIOS
    CFRCF          = "rcf",
    CIOSPRF        = "srf",
/
&NAMFPG
/
&NAMCT0
    LNHDYN         = FALSE,
    NCONF          = 1,
    CTYPE          = "fc",
    CNMEXP         = "test",
    CFCLASS        = "se",
    LECMWF         = TRUE,
    LARPEGEF       = FALSE,
    LFDBOP         = FALSE,
    LFPOS          = TRUE,
    LSMSSIG        = FALSE,
    LSPRT          = TRUE,
    LSLAG          = TRUE,
    LTWOTL         = TRUE,
    LVERTFE        = TRUE,
    LAPRXPK        = TRUE,
    LOPT_SCALAR    = TRUE,
    LPC_FULL       = FALSE,
    LPC_CHEAP      = FALSE,
    LPC_NESC       = FALSE,
    LPC_NESCT      = FALSE,
    LSLPHY         = TRUE,
    LRFRIC         = TRUE,
    LFPSPEC        = FALSE,
    N3DINI         = 0,
    NSTOP          = $(( leg_end_sec / ifs_time_step_sec )),
    NFRDHP         = ${ifs_ddh_freq},
    NFRSDI         = ${ifs_di_freq},
    NFRGDI         = ${ifs_di_freq},
    NFRPOS         = ${ifs_output_freq},
    NFRHIS         = ${ifs_output_freq},
    NFRMASSCON     = $(( 6 * 3600 / ifs_time_step_sec )),
    NPOSTS         = 0,
    NHISTS         = 0,
    NMASSCONS      = 0,
    NFRCO          = ${NFRCO},
    NFRCO_CHEM     = ${NFRCO_CHEM},
    NFRCO_VEG      = ${NFRCO_VEG},
    LTM5CO2        = ${LTM5CO2},
    NLEV_TM5       = ${NLEV_TM5},
    NFRDHFZ        = 48,
    NDHFZTS        = 0,
    NDHFDTS        = 0,
    LWROUTLAST     = ${ifs_lastout},
    CFDIRLST       = "dirlist",
    CNPPATH        = "postins",
/
&NAMDDH
    BDEDDH(1,1)    = 4.0,1.0,0.0,50.0,0.0,49.0,
    NDHKD          = 120,
    LHDZON         = FALSE,
    LHDEFZ         = FALSE,
    LHDDOP         = FALSE,
    LHDEFD         = FALSE,
    LHDGLB         = TRUE,
    LHDPRG         = TRUE,
    LHDHKS         = TRUE,
/
&NAMGFL
    LTRCMFIX       = TRUE,
    NERA40         = 0,
    YQ_NL%LGP      = TRUE,
    YQ_NL%LSP      = FALSE,
    YL_NL%LGP      = TRUE,
    YI_NL%LGP      = TRUE,
    YA_NL%LGP      = TRUE,
    YO3_NL%LGP     = FALSE,
    YQ_NL%LGPINGP  = TRUE,
    YL_NL%LQM      = TRUE,
    YI_NL%LQM      = TRUE,
    YR_NL%LQM      = TRUE,
    YS_NL%LQM      = TRUE,
    YQ_NL%LMASSFIX = TRUE,
    YL_NL%LMASSFIX = TRUE,
    YI_NL%LMASSFIX = TRUE,
    YR_NL%LMASSFIX = TRUE,
    YS_NL%LMASSFIX = TRUE,
    YCDNC_NL%LGP   = TRUE,
    YICNC_NL%LGP   = TRUE,
    YRE_LIQ_NL%LGP = TRUE,
    YRE_ICE_NL%LGP = TRUE,
    YCDNC_NL%CNAME = "CDNC",
    YICNC_NL%CNAME = "ICNC",
    YRE_LIQ_NL%CNAME ="Reff_liq",
    YRE_ICE_NL%CNAME ="Reff_ice",
/
&NAMFPC
    CFPFMT         = "MODEL",
    NFP3DFS        = 5,
    NFP3DFP        = 7,
    NFP3DFT        = 1,
    NFP3DFV        = 1,
    MFP3DFS        = 130,135,138,155,133,
    MFP3DFP        = 129,130,135,138,155,157,133,
    MFP3DFT        = 60,
    MFP3DFV        = 133,
    NFP2DF         = 2,
    MFP2DF         = 129,152,
    NFPPHY         = 78,
    MFPPHY         = 31,32,33,34,35,36,37,38,39,40,41,42,44,45,49,50,57,58,59,78,79,129,136,137,139,141,142,143,144,145,146,147,148,151,159,164,165,166,167,168,169,170,172,175,176,177,178,179,180,181,182,183,186,187,188,189,195,196,197,198,201,202,205,208,209,210,211,235,236,238,243,244,245,229,230,231,232,213,
    NRFP3S         = 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,
    RFP3P          = 100000.0,92500.0,85000.0,70000.0,50000.0,40000.0,30000.0,25000.0,20000.0,15000.0,10000.0,7000.0,5000.0,3000.0,2000.0,1000.0,700.0,500.0,300.0,200.0,100.0,
    LFITP          = TRUE,
    LFITT          = FALSE,
    LFITV          = FALSE,
    NFPCLI         = 0,
    LFPQ           = FALSE,
    LASQ           = FALSE,
    LTRACEFP       = FALSE,
    RFPCORR        = 60000.,
/
&NAMFPD
/
&NAMDIM
    NPROMA         = 0,
    NUNDEFLD       = 0,
/
&NAMVAR
    LMODERR        = FALSE,
    LJCDFI         = FALSE,
    LUSEJCDFI      = FALSE,
/
&NAMMCC
    LMCCIEC        = TRUE,
    LMCCEC         = TRUE,
    LMCC04         = TRUE,
    NOACOMM        = 5,
    LMCCICEIC      = FALSE,
    LRDALB         = FALSE, 
    LRDVEG         = TRUE, 
    LPISM          = FALSE,
    LLANDICE       = ${ifs_landice},
/
&NAMPPC
    LRSACC         = TRUE,
/
&NAMORB
    LCORBMD =  $ifs_orb_switch,
    ORBMODE = '$ifs_orb_mode',
    ORBIY   =  $ifs_orb_iyear,
/
EOF

# Resolution-dependent gravity wave drag parametrisation - using cy41r2 version
# GFLUXLAUN=GFLUXLAUN*(1.0_JPRB-MIN(1.0_JPRB,atan((MAX(KSMAX,700)-700)/REAL(6000-700))))
case ${ifs_grid} in
T799L91)
GFLUXLAUN=0.00367996
;;
T1279L91)
GFLUXLAUN=0.00334195
;;
*)
GFLUXLAUN=0.00375
;;
esac

cat << EOF
&NAMGWWMS
    GFLUXLAUN=$GFLUXLAUN
    ZLAUNCHP=45000
    LOZPR=true
    NGAUSS=2
    GGAUSSB=-0.55
/
&NAMGWD
    GTENLIM=0.0222
/
EOF

# Add COSP namelist if needed
has_config ifs:cosp && . $ctrl_file_dir/namelist.cosp.alldiag.sh

cat << EOF
&NAEAER
/
&NALBAR
/
&NALORI
/
&NAM_DISTRIBUTED_VECTORS
/
&NAM926
/
&NAMAFN
/
&NAMANA
/
&NAMARPHY
/
&NAMCA
/
&NAMCAPE
/
&NAMCFU
/
&NAMCHK
/
&NAMCHET
/
&NAMCLDP
    NCLDDIAG   = 0,
    RLCRITSNOW = $RLCRITSNOW,
    RVICE      = $RVICE,
    RCLDIFF    = $RCLDIFF,
    RCLDIFFC   = $RCLDIFFC,
    RTAUMEL    = 7200.0,
    RSNOWLIN2  = $RSNOWLIN2,
    RCLCRIT    = 0.4E-3,
    NCLOUDACT  = 2,
    NACTPDF    = 10,
    NAERCLD    = 9,
    RLCRIT_UPHYS=$RLCRIT_UPHYS,
    LACI_DIAG  = .TRUE.,
/
&NAMCLTC
/
&NAMCOM
/
&NAMCOS
/
&NAMCTAN
/
&NAMCOSPINPUT
/
&NAMCOSPOUTPUT
/
&NAMCUMF
    ENTRORG = $ENTRORG,
    ENTRDD  = $ENTRDD,
    RPRCON  = $RPRCON,
    DETRPEN = $DETRPEN,
    RMFDEPS = $RMFDEPS,
/
&NAMCUMFS
/
&NAMCT1
/
&NAMCVA
/
&NAMDFHD
/
&NAMDFI
/
&NAMDIF
/
&NAMDIMO
/
&NAMDMSP
/
&NAMDPHY
 NVXTR2=20,
 NVEXTR=3,
 NCEXTR=91,
/
&NAMDYNA
/
&NAMEMIS_CONF
/
&NAMENKF
/
&NAMFA
/
&NAMFFT
/
&NAMFPDY2
/
&NAMFPDYH
/
&NAMFPDYP
/
&NAMFPDYS
/
&NAMFPDYT
/
&NAMFPDYV
/
&NAMFPEZO
/
&NAMFPF
/
&NAMFPIOS
/
&NAMFPPHY
/
&NAMFPSC2
/
&NAMFPSC2_DEP
/
&NAMFY2
/
&NAMGEM
/
&NAMGMS
/
&NAMGOES
/
&NAMGOM
/
&NAMGRIB
    NENSFNB = ${NENSFNB},
/
&NAMGWD
/
&NAMGWWMS
/
&NAMHLOPT
/
&NAMINI
/
&NAMIOMI
/
&NAMJBCODES
/
&NAMJFH
/
&NAMJG
/
&NAMJO
/
&NAMKAP
/
&NAMLCZ
/
&NAMLEG
/
&NAMLFI
/
&NAMMCUF
/
&NAMMETEOSAT
/
&NAMMTS
/
&NAMMTSAT
/
&NAMMTT
/
&NAMMUL
/
&NAMNASA
/
&NAMNN
/
&NAMNPROF
/
&NAMNUD
/
&NAMOBS
/
&NAMONEDVAR
/
&NAMOPH
/
&NAMPARAR
/
&NAMPHY
/
&NAMPHY0
/
&NAMPHY1
/
&NAMPHY2
/
&NAMPHY3
/
&NAMPHYDS
 NVEXTRAGB=126020,126021,126022,
 NVEXTR2GB=126040,126041,126042,126043,126044,126045,126046,126047,126048,126049,126001,126002,126068,126069,126070,126071,126072,126073,126074,126075,
/
&NAMPONG
/
&NAMRAD15
/
&NAMRCOEF
/
&NAMRINC
/
&NAMRIP
/
&NAMRLX
    LRLXG          = ${LRLXG},
    LRLXVO         = FALSE,
    LRLXDI         = FALSE,
    LRLXTE         = FALSE,
    LRLXQ          = FALSE,
    LRLXQL         = FALSE,
    LRLXQI         = FALSE,
    LRLXQC         = FALSE,
    LRLXLP         = FALSE,
    XRLXVO         = 0.1,
    XRLXDI         = 0.1,
    XRLXTE         = 0.1,
    XRLXQ          = 0.1,
    XRLXLP         = 0.1,
    ALATRLX1       = 90,
    ALATRLX2       = -90,
    ALONRLX1       = 0,
    ALONRLX2       = 360,
    AXRLX          = -0.5,
    AYRLX          = -0.5,
    AZRLX          = 1.0,
    NRLXLMIN       = 1,
    NRLXLMAX       = 91,
/
&NAMSCC
/
&NAMSCEN
/
&NAMSCM
/
&NAMSENS
/
&NAMSIMPHL
/
&NAMSKF
/
&NAMSPSDT
    LFIXSPPT	    = ${LFIXSPPT},
    LSPSDT          = ${LSPSDT},
    LCLIP_SPEC_SDT  = TRUE,
    LCLIP_GRID_SDT  = TRUE,
    LWRITE_ARP      = FALSE,
    LUSESETRAN_SDT  = TRUE,
    LRESETSEED_SDT  = FALSE,
    NSCALES_SDT     = 3,
    CSPEC_SHAPE_SDT ='WeaverCourtier',
    SDEV_SDT        = 0.52,0.18,0.06,
    TAU_SDT         = 2.16E4,2.592E5,2.592E6,
    XLCOR_SDT       = 500.E3,1000.E3,2000.E3,
    XCLIP_RATIO_SDT = 1.8,
    LTAPER_BL0      = TRUE,
    XSIGMATOP       = 0.87,
    XSIGMABOT       = 0.97,
    LTAPER_ST0      = TRUE,
    XPRESSTOP_ST0   = 50.E2,
    XPRESSBOT_ST0   = 100.E2,
    LQPERTLIMIT2    = TRUE,
/
&NAMSTA
/
&NAMSTOPH
/
&NAMTCWV
/
&NAMTESTVAR
/
&NAMTLEVOL
/
&NAMTOPH
/
&NAMTOVS
/
&NAMTRAJP
/
&NAMTRANS
/
&NAMTRM
/
&NAMVARBC
/
&NAMVARBC_AIREP
/
&NAMVARBC_ALLSKY
/
&NAMVARBC_RAD
/
&NAMVARBC_TCWV
/
&NAMVARBC_TO3
/
&NAMVAREPS
/
&NAMVDOZ
/
&NAMVFP
/
&NAMVRTL
/
&NAMVV1
/
&NAMVV2
/
&NAMVWRK
/
&NAMXFU
/
&NAMZDI
/
&NAPHLC
/
&NAV1IS
/
EOF
