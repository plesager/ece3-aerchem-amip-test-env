# flist_* can hold lists of files, separated by commas
flist_sst=\'${ini_data_dir}/amip-forcing/tosbcs_input4MIPs_SSTsAndSeaIce_CMIP_PCMDI-AMIP-1-1-9_gn_187001-202212.nc\'
flist_sic=\'${ini_data_dir}/amip-forcing/siconcbcs_input4MIPs_SSTsAndSeaIce_CMIP_PCMDI-AMIP-1-1-9_gn_187001-202212.nc\'

cat << EOF
!-----------------------------------------------------------------------
&NAMAMIP
!-----------------------------------------------------------------------
    RunLengthSec = ${leg_length_sec}
    TimeStepSec  = ${cpl_freq_amip_sec}
    StartYear    = ${leg_start_date_yyyymmdd:0:4}
    StartMonth   = ${leg_start_date_yyyymmdd:4:2}
    StartDay     = ${leg_start_date_yyyymmdd:6:2}
    FixYear      = ${ifs_cmip_fixyear}
    FileListSST  = ${flist_sst}
    FileListSIC  = ${flist_sic}
    LDebug       = false
    LInterpolate = true
!-----------------------------------------------------------------------
/
EOF
