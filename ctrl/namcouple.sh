# namcouple.sh writes the OASIS3-MCT namcouple file to standard out. The
# content of the file is based on the selected components in the $config
# variable (function has_config)

# Set coupling frequencies (in seconds) between components
(( ${cpl_freq_atm_oce_sec:-}  )) && cpl_freq_atm_oce_sec=${cpl_freq_atm_oce_sec}
(( ${cpl_freq_atm_ctm_hrs:-}  )) && cpl_freq_atm_ctm_sec=$(( cpl_freq_atm_ctm_hrs * 3600 ))
(( ${cpl_freq_atm_lpjg_hrs:-} )) && cpl_freq_atm_lpjg_sec=$(( cpl_freq_atm_lpjg_hrs * 3600 ))
cpl_freq_ccycle_sec=$(( 24 * 3600 ))

# Set coupling field lags
(( ${ifs_time_step_sec:-} )) && lag_atm_oce=${ifs_time_step_sec}
(( ${nem_time_step_sec:-} )) && lag_oce_atm=${nem_time_step_sec}
(( ${ifs_time_step_sec:-} )) && lag_atm_ctm=${ifs_time_step_sec}
(( ${tm5_time_step_sec:-} )) && lag_ctm_atm=${tm5_time_step_sec}
(( ${ifs_time_step_sec:-} )) && (( ${cpl_freq_atm_ctm_sec:-} )) && \
    lag_atm_ctm_mid=$(( (((cpl_freq_atm_ctm_sec / ifs_time_step_sec)+1)/2 +1) * ifs_time_step_sec ))
(( ${ifs_time_step_sec:-} )) && lag_atm_lpjg=${ifs_time_step_sec} || lag_atm_lpjg=0
(( ${lpjg_time_step_sec:-} )) && lag_lpjg_atm=${lpjg_time_step_sec} || lag_lpjg_atm=0

# Set lucia variable to produce the logs for a post processing analysis
(( ${lucia:-} )) || lucia=''

# Check consistency of model timesteps and coupling frequencies
ck_cpl_freq(){
    # expects to be called as: ck_cpl_freq  coupling_frequency  model_timestep
    if (($(($1%$2))))
    then
        echo "*EE* model timestep $2 does not divide coupling frequency $1 " 1>&2
        return 1
    fi
}

if has_config ifs tm5
then
    ck_cpl_freq $cpl_freq_atm_ctm_sec $tm5_time_step_sec || exit 1 
    ck_cpl_freq $cpl_freq_atm_ctm_sec $ifs_time_step_sec || exit 1 
fi
if has_config ifs nemo
then
    ck_cpl_freq $cpl_freq_atm_oce_sec $nem_time_step_sec || exit 1 
    ck_cpl_freq $cpl_freq_atm_oce_sec $ifs_time_step_sec || exit 1 
fi


# Atmosphere/Land grids (note that TM5 and LPJG require IFS)
if (( ${ifs_res_hor:-} ))
then
    # IFS grid point grids
    case ${ifs_res_hor} in
        159) atm_grid=A080
             ;;
        255) atm_grid=A128
             ;;
        511) atm_grid=A256
             ;;
        799) atm_grid=A400
             ;;
        *)   echo "*EE* Unsupported horizontal resolution (IFS): ${ifs_res_hor}" 1>&2
             exit 1
             ;;
    esac

    # LPJG
    lpjg_grid=${atm_grid}

    # IFS grid point grids without land-sea mask
    atm_grid_nm=$(echo ${atm_grid} | sed 's/A/B/')

    # IFS/TM5 spectral grids
    atm_grid_sh=T${ifs_res_hor}
    ctm_grid_sh=C${ifs_res_hor}

    # TM5 grid point grids (C: no mask, L: land masked; O: ocean masked)
    ctm_grid=CTM3
    ctm_nx=120
    ctm_ny=90
    #
    ctm_grid_sfc=CTM1
    ctm_nx_sfc=360
    ctm_ny_sfc=180
fi

# NEMO grids
(( ${nem_res_hor:-} )) && case ${nem_res_hor} in
      1) oce_grid=O1t0
         ;;
    025) oce_grid=Ot25
         ;;
    *)   echo "*EE* Unsupported horizontal resolution (NEMO): ${nem_res_hor}" 1>&2
         exit 1
         ;;
esac


# Functions expcat and explvl expand their arguments into coupling field names
# with the appropriate extensions for categories/levels and according to the
# syntax needed in the namcouple file.
#
# Usage: expcat NUM FLDA FLDB
#        explvl NUM_START NUM_END FLDA FLDB
#
function expcat()
{
    printf  "$2.C%.3d" 1
    [ $1 -gt 1 ] && printf ":$2.C%.3d" $(eval echo {2..$1})

    printf  " $3.C%.3d" 1
    [ $1 -gt 1 ] && printf ":$3.C%.3d" $(eval echo {2..$1})
}
function explvl()
{
    printf  "$3.L%.3d" $1
    [ $2 -gt $1 ] && printf ":$3.L%.3d" $(eval echo {$(($1+1))..$2})

    printf  " $4.L%.3d" $1
    [ $2 -gt $1 ] && printf ":$4.L%.3d" $(eval echo {$(($1+1))..$2})
}

# Functions expfield_* split one 3D variable into \$nbundle namcouple entries.
# They are dedicated to TM5-IFS coupling.
# 
# ***** MACHINE DEPENDENCY - there is an optimum number of levels you can bundle:
# Set nbundle to \$tm5_exch_nlevs for one entry per level,
# set it to 1 to bundle all levels into one entry.
# The smaller nbundle is, the faster the coupling is. But if too small, the
# model may start swapping. 
# nbundle_cutoff is for the feedback (done with 24 of 34 levels, or all levels)

if has_config tm5
then
    [[ ${tm5_exch_nlevs} == 34 ]] && nbundle=3 && nbundle_cutoff=2
    [[ ${tm5_exch_nlevs} == 10 ]] && nbundle=1 && nbundle_cutoff=1
    [[ ${tm5_exch_nlevs} == 4  ]] && nbundle=1 && nbundle_cutoff=1

    nlev=${tm5_exch_nlevs:-999}
    (( $nbundle > $nlev )) && nbundle=$nlev
    ia=$(($nlev/$nbundle))
    ib=$(($nlev%$nbundle))

    nlev_cutoff=${tm5_exch_nlevs_cutoff:-999}
    (( $nbundle_cutoff > $nlev_cutoff )) && nbundle_cutoff=$nlev_cutoff
    ia_cutoff=$(($nlev_cutoff/$nbundle_cutoff))
    ib_cutoff=$(($nlev_cutoff%$nbundle_cutoff))
fi

function expfield_sh()
{
    # args = ifs-var, tm5-var, CF-code, restart, header
    for k in $(eval echo {1..$nbundle})
    do
        start=$(( (k-1)*ia+1 )) 
        extra=$(( (k-1)<ib?(k-1):ib ))
        start=$(( start+extra ))
        end=$(( start + ia - 1 ))
        (( ib>(k-1) )) && ((end+=1))
        cat <<EOF
#
  $(explvl $start $end $1 $2) $3 ${cpl_freq_atm_ctm_sec} 1 $4 EXPORTED
  ${atm_grid_sh} ${ctm_grid_sh} LAG=${lag_atm_ctm_mid}
  P  0  P  0
  LOCTRANS
   INSTANT
EOF
    done
}

function expfield_gg()
{
    # args = ifs-var, tm5-var, CF-code, restart, lag, header (not used)
    for k in $(eval echo {1..$nbundle})
    do
        start=$(( (k-1)*ia+1 )) 
        extra=$(( (k-1)<ib?(k-1):ib ))
        start=$(( start+extra ))
        end=$(( start + ia - 1 ))
        (( ib>(k-1) )) && ((end+=1))
        cat <<EOF
#
  $(explvl $start $end $1 $2) $3 ${cpl_freq_atm_ctm_sec} 1 $4 EXPORTED
  ${atm_grid_nm} ${ctm_grid} LAG=$5
  P  0  P  0
  SCRIPR
   GAUSWGT D SCALAR LATITUDE 90 9 2.0
EOF
    done
}

function expfield_gg_aver()
{
    # args = ifs-var, tm5-var, CF-code, restart, lag, header (not used)
    for k in $(eval echo {1..$nbundle})
    do
        start=$(( (k-1)*ia+1 )) 
        extra=$(( (k-1)<ib?(k-1):ib ))
        start=$(( start+extra ))
        end=$(( start + ia - 1 ))
        (( ib>(k-1) )) && ((end+=1))
        cat <<EOF
#
  $(explvl $start $end $1 $2) $3 ${cpl_freq_atm_ctm_sec} 2 $4 EXPORTED
  ${atm_grid_nm} ${ctm_grid} LAG=$5
  P  0  P  0
  LOCTRANS SCRIPR
   AVERAGE
   GAUSWGT D SCALAR LATITUDE 90 9 2.0
EOF
    done
}

function expfield_fbck()
{
    # args = tm5-var, ifs-var, CF-code, restart, lag, header (not used)
    for k in $(eval echo {1..$nbundle})
    do
        start=$(( (k-1)*ia+1 )) 
        extra=$(( (k-1)<ib?(k-1):ib ))
        start=$(( start+extra ))
        end=$(( start + ia - 1 ))
        (( ib>(k-1) )) && ((end+=1))
        cat <<EOF
#
  $(explvl $start $end $1 $2) $3 ${cpl_freq_atm_ctm_sec} 1 $4 EXPORTED
  ${ctm_grid} ${atm_grid_nm} LAG=$5
  P  0  P  0
   SCRIPR
   BILINEAR LR SCALAR LATITUDE 16
EOF
    done
}


function expfield_fbck_ccycle()
{
    # args = tm5-var, ifs-var, CF-code, restart, lag, header (not used)
    for k in $(eval echo {1..$nbundle})
    do
        start=$(( (k-1)*ia+1 )) 
        extra=$(( (k-1)<ib?(k-1):ib ))
        start=$(( start+extra ))
        end=$(( start + ia - 1 ))
        (( ib>(k-1) )) && ((end+=1))
        cat <<EOF
#
  $(explvl $start $end $1 $2) $3 ${cpl_freq_ccycle_sec} 1 $4 EXPORTED
  ${ctm_grid} ${atm_grid_nm} LAG=$5
  P  0  P  0
   SCRIPR
   BILINEAR LR SCALAR LATITUDE 16
EOF
    done
}

function expfield_fbck_cutoff()
{
    # args = tm5-var, ifs-var, CF-code, restart, lag, header (not used)
    for k in $(eval echo {1..$nbundle_cutoff})
    do
        start=$(( (k-1)*ia_cutoff+1 ))
        extra=$(( (k-1)<ib_cutoff?(k-1):ib_cutoff ))
        start=$(( start+extra ))
        end=$(( start + ia_cutoff - 1 ))
        (( ib_cutoff>(k-1) )) && ((end+=1))
        cat <<EOF
#
  $(explvl $start $end $1 $2) $3 ${cpl_freq_atm_ctm_sec} 1 $4 EXPORTED
  ${ctm_grid} ${atm_grid_nm} LAG=$5
  P  0  P  0
   SCRIPR
   BILINEAR LR SCALAR LATITUDE 16
EOF
    done
}

# workaround for lpjg_forcing and OSM (which replaces IFS as seen from LPJG)
has_config lpjg_forcing && config=$config" "atm
has_config osm && config=$config" "atm
has_config ifs && config=$config" "atm

# define output strategy for c-cycle fluxes
[[ ${ccycle_debug_fluxes:-} == true ]] && ccycle_out_fluxes="EXPOUT" || ccycle_out_fluxes="EXPORTED"

# Configure number of coupling fields
# Note that the || : terms after the arithmetic expression is necessary to
# prevent set -e from stopping the script depending on the outcome of the
# expression.
nfields=0

has_config ifs nemo rnfmapper && (( nfields+=9  ))                || :
has_config atm lpjg           && (( nfields+=20 ))                || :
has_config ifs amip           && (( nfields+=1  ))                || :
# ifs -> tm5
has_config ifs tm5:co2        && (( nfields+=(12 +  8*nbundle) )) || :
has_config ifs tm5:chem       && (( nfields+=(39 + 13*nbundle) )) || :
# tm5 -> ifs
has_config ifs tm5:o3fb       && (( nfields+=nbundle      ))      || :
has_config ifs tm5:ch4fb      && (( nfields+=nbundle      ))      || :
has_config ifs tm5:co2fb      && (( nfields+=nbundle      ))      || :
has_config ifs tm5:aerfb      && (( nfields+=(67*nbundle_cutoff) )) || :
# tm5 <-> lpjg
has_config lpjg tm5:co2       && (( nfields+=2 ))                 || :
# tm5 <-> pisces
has_config pisces tm5:co2     && (( nfields+=2 ))                 || :

# The following while loop reads the rest of this file (until the
# END_OF_NAMCOUPLE marker) and processes any #defcfg and #enddef directives.
# Note that the "IFS=" at the loop header is necessary to preserve leading
# spaces. (IFS stands for Input Field Separator and has nothing to do with the
# atmosphere model)
#
# The $lineout variable controls whether a particular line is send to standard
# out. It is set to true before the loop as a default.
#
# Set 'set +u' is necessary because Bash here-documents (the part
# between '<<END_OF_NAMCOUPLE' and 'END_OF_NAMCOUPLE') expands shell variables
# and this part may contain undefined variables.
lineout=1
set +u
while IFS= read line
do
    # Skip empty lines
    [[ $line =~ ^[[:blank:]]*$ ]] && continue

    # Process lines that start with #defcfg
    if [[ $line =~ ^#defcfg ]]
    then
        # Get the config string, i.e. everything after #defcfg and before the
        # second # character.
        # Note the ||: at the end of the expression! It is necessary because
        # set -e would otherwise abort the script when no comment is found.
        cfgstring=$(expr "$line" : '^#defcfg[[:blank:]]*\([^#]*\)' || :)

        # Set $lineout depending on whether has_config returns true or false
        has_config $cfgstring && lineout=1 || lineout=0

        # Get the comment, i.e. everyting starting from the second # character
        # Note the ||: at the end of the expression!
        comment=$(expr "$line" : '^#defcfg[^#]*[[:blank:]]*\(.*\)' || :)

        # Output the comment (with the config string from defcfg added) if
        # $lineout is true and if the comment is not empty
        (( lineout )) && [[ -n "$comment" ]] && echo "$comment [$(echo $cfgstring)]"

    # Process #enddef lines: reset $lineout
    elif [[ $line =~ ^#enddef ]]
    then
        lineout=1

    # Process lines that create bundles of 3D variables
    elif [[ $line =~ ^expfield ]]
    then
        (( lineout )) && $line

    # Process any other lines (output according to $lineout)
    else
        (( lineout )) && echo "$line"
    fi
done << END_OF_NAMCOUPLE
# =================================================================================================
# General OASIS configuration
# =================================================================================================
 \$NFIELDS
    ${nfields}
 \$END
# -------------------------------------------------------------------------------------------------
 \$RUNTIME
    ${leg_length_sec}
 \$END
# -------------------------------------------------------------------------------------------------
 \$NLOGPRT
    0 ${lucia}
 \$END
# -------------------------------------------------------------------------------------------------
 \$STRINGS

#defcfg ifs nemo
# =================================================================================================
# Fields send from Atmosphere to Ocean
# =================================================================================================
#enddef

#defcfg ifs nemo # --- Momentum fluxes for oce and ice on U grid ---
  A_TauX_oce:A_TauY_oce:A_TauX_ice:A_TauY_ice O_OTaux1:O_OTauy1:O_ITaux1:O_ITauy1 1 ${cpl_freq_atm_oce_sec} 2 rstas.nc EXPORTED
  ${atm_grid} ${oce_grid/t/u} LAG=${lag_atm_oce}
  P  0  P  2
  LOCTRANS SCRIPR
   AVERAGE
   GAUSWGT D SCALAR LATITUDE 1 9 2.0
#enddef

#defcfg ifs nemo # --- Momentum fluxes for oce and ice on V grid ---
  A_TauX_oce:A_TauY_oce:A_TauX_ice:A_TauY_ice O_OTaux2:O_OTauy2:O_ITaux2:O_ITauy2 1 ${cpl_freq_atm_oce_sec} 2 rstas.nc EXPORTED
  ${atm_grid} ${oce_grid/t/v} LAG=${lag_atm_oce}
  P  0  P  2
  LOCTRANS SCRIPR
   AVERAGE
   GAUSWGT D SCALAR LATITUDE 1 9 2.0
#enddef

#defcfg ifs nemo # --- Non-solar and solar radiation over ocean+ice, total evaporation, precipitation (conserved, preserved sign) ---
  A_Qns_mix:A_Qs_mix:A_Evap_total:A_Precip_liquid:A_Precip_solid O_QnsMix:O_QsrMix:OTotEvap:OTotRain:OTotSnow 1 ${cpl_freq_atm_oce_sec} 3 rstas.nc EXPORTED
  ${atm_grid} ${oce_grid} LAG=${lag_atm_oce}
  P  0  P  2
  LOCTRANS SCRIPR CONSERV
   AVERAGE
   GAUSWGT D SCALAR LATITUDE 1 9 2.0
   GLBPOS opt
#enddef

#defcfg ifs nemo # --- Solar/non-solar radiation over ice, dQns/dT, evaporation over ice (not conserved) ---
  A_Qs_ice:A_Qns_ice:A_dQns_dT:A_Evap_ice O_QsrIce:O_QnsIce:O_dQnsdT:OIceEvap 1 ${cpl_freq_atm_oce_sec} 2 rstas.nc EXPORTED
  ${atm_grid} ${oce_grid} LAG=${lag_atm_oce}
  P  0  P  2
  LOCTRANS SCRIPR
   AVERAGE
   GAUSWGT D SCALAR LATITUDE 1 9 2.0
#enddef

#defcfg ifs rnfmapper
# =================================================================================================
# Fields send from Atmosphere to Runoff mapper
# =================================================================================================
#enddef

#defcfg ifs rnfmapper # --- Runoff + Calving ---
  A_Runoff:A_Calving R_Runoff_atm:R_Calving_atm 1 ${cpl_freq_atm_oce_sec} 3 rstas.nc EXPORTED
  ${atm_grid/A/R} RnfA LAG=${lag_atm_oce}
  P  0  P  0
  LOCTRANS SCRIPR CONSERV
   AVERAGE
   GAUSWGT D SCALAR LATITUDE 1 9 2.0
   GLBPOS opt
#enddef

#defcfg rnfmapper nemo
# =================================================================================================
# Fields send from Runoff mapper to the Ocean
# =================================================================================================
#enddef

#defcfg rnfmapper nemo # --- Runoff ---
  R_Runoff_oce O_Runoff 1 ${cpl_freq_atm_oce_sec} 3 rstas.nc EXPORTED
  RnfO ${oce_grid} LAG=0
  P  0  P  2
  SCRIPR CONSERV BLASNEW
   GAUSWGT LR SCALAR LATITUDE 1 9 2.0
   GLBPOS opt
   ${oas_mb_fluxcorr} 0
#enddef

#defcfg rnfmapper nemo # --- Calving ---
  R_Calving_oce OCalving 1 ${cpl_freq_atm_oce_sec} 2 rstas.nc EXPORTED
  RnfO ${oce_grid} LAG=0
  P  0  P  2
  SCRIPR CONSERV
   GAUSWGT LR SCALAR LATITUDE 1 9 2.0
   GLBPOS opt
#enddef

#defcfg ifs nemo
# =================================================================================================
# Fields send from Ocean to Atmosphere
# =================================================================================================
#enddef

#defcfg ifs nemo # --- SST, ice temperature, albedo, fraction, thickness; snow thickness over ice ---
  O_SSTSST:O_TepIce:O_AlbIce:OIceFrc:OIceTck:OSnwTck A_SST:A_Ice_temp:A_Ice_albedo:A_Ice_frac:A_Ice_thickness:A_Snow_thickness 1 ${cpl_freq_atm_oce_sec} 2 rstos.nc EXPORTED
  ${oce_grid} ${atm_grid/A/L} LAG=${lag_oce_atm}
  P  2  P  0
  LOCTRANS SCRIPR
   AVERAGE
   GAUSWGT LR SCALAR LATITUDE 1 9 2.0
#enddef

#defcfg ifs tm5
# =================================================================================================
# Fields send from Atmosphere to CTM
# =================================================================================================
#enddef

#defcfg ifs tm5 # --- Surface air pressure ---
  A_LNSP C_LNSP 348 ${cpl_freq_atm_ctm_sec}  1 r_s2d.nc EXPORTED
  ${atm_grid_sh} ${ctm_grid_sh} LAG=${lag_atm_ctm_mid}
  P  0  P  0
  LOCTRANS
   INSTANT
#enddef

#defcfg ifs tm5 # --- Potential vorticity of atmosphere layer ---
expfield_sh A_VOR C_VOR 273 r_vor.nc
#enddef

#defcfg ifs tm5 # --- Divergence of wind ---
expfield_sh A_DIV C_DIV 168 r_div.nc
#enddef

#defcfg ifs tm5 # --- Geopotential  ---
  A_OROG C_OROG 194 ${cpl_freq_atm_ctm_sec}  1 r_g2d.nc EXPORTED
  ${atm_grid_nm} ${ctm_grid_sfc} LAG=${lag_atm_ctm}
  P  0  P  0
  SCRIPR
   BILINEAR D SCALAR LATITUDE 90
#enddef

#defcfg ifs tm5 # --- Surface air pressure ---
  A_SPRES C_SPRES 33 ${cpl_freq_atm_ctm_sec}  1 r_g2d.nc EXPORTED
  ${atm_grid_nm} ${ctm_grid} LAG=${lag_atm_ctm}
  P  0  P  0
  SCRIPR
   GAUSWGT D SCALAR LATITUDE 90 9 2.0
#enddef

#defcfg ifs tm5 # --- Air temperature ---
expfield_gg A_TMP C_TMP 110 r_tmp.nc ${lag_atm_ctm_mid} "# --------------- Field 7: Air temperature ---------------"
#enddef

#defcfg ifs tm5 # --- Relative humidity  ---
expfield_gg A_HUM C_HUM 295 r_hum.nc ${lag_atm_ctm_mid} "# --------------- Field 8: Relative humidity  ---------------"
#enddef

#defcfg ifs tm5:chem # --- Atmosphere cloud liquid water content ---
expfield_gg A_CLW C_CLW 119 r_clw.nc ${lag_atm_ctm_mid} "# --------------- Field 9: Atmosphere cloud liquid water content ---------------"
#enddef

#defcfg ifs tm5:chem # --- Atmosphere cloud ice content ---
expfield_gg A_CIW C_CIW 118 r_ciw.nc ${lag_atm_ctm_mid} "# --------------- Field 10: Atmosphere cloud ice content ---------------"
#enddef

#defcfg ifs tm5:chem # --- Cloud area fraction ---
expfield_gg A_CC  C_CC  143 r_cc_.nc ${lag_atm_ctm_mid} "# --------------- Field 11: Cloud area fraction ---------------"
#enddef

#defcfg ifs tm5:chem # --- Cloud area fraction ---
expfield_gg A_CCO C_CCO 143 r_cco.nc ${lag_atm_ctm_mid} "# --------------- Field 12: Cloud area fraction ---------------"
#enddef

#defcfg ifs tm5:chem # --- Cloud area fraction ---
expfield_gg A_CCU C_CCU 143 r_ccu.nc ${lag_atm_ctm_mid} "# --------------- Field 13: Cloud area fraction ---------------"
#enddef

#defcfg ifs tm5 # --- Mass transport ---
expfield_gg_aver A_UMF C_UMF 245 r_umf.nc ${lag_atm_ctm}     "# --------------- Field 14: Untrainment ---------------"
#enddef

#defcfg ifs tm5 # --- Cloud area fraction ---
expfield_gg_aver A_UDR C_UDR 245 r_udr.nc ${lag_atm_ctm}     "# --------------- Field 15: Untrainment ---------------"
#enddef

#defcfg ifs tm5 # --- Mass transport ---
expfield_gg_aver A_DMF C_DMF 245 r_dmf.nc ${lag_atm_ctm}     "# --------------- Field 16: Detrainment ---------------"
#enddef

#defcfg ifs tm5 # --- Mass transport ---
expfield_gg_aver A_DDR C_DDR 245 r_ddr.nc ${lag_atm_ctm}     "# --------------- Field 17: Detrainment ---------------"
#enddef

#defcfg ifs tm5 # --- Land Sea Mask ---
  A_LSMSK C_LSMSK 206 ${cpl_freq_atm_ctm_sec}  1 r_g2d.nc EXPORTED
  ${atm_grid_nm} ${ctm_grid_sfc} LAG=${lag_atm_ctm_mid}
  P  0  P  0
  SCRIPR
   BILINEAR D SCALAR LATITUDE 90
#enddef

#defcfg ifs tm5:chem # --- Surface albedo ---
  A_ALB C_ALB 17 ${cpl_freq_atm_ctm_sec}  1 r_g2d.nc EXPORTED
  ${atm_grid_nm} ${ctm_grid_sfc} LAG=${lag_atm_ctm_mid}
  P  0  P  0
  SCRIPR
   BILINEAR D SCALAR LATITUDE 90
#enddef

#defcfg ifs tm5 # --- Surface roughness length ---
  A_SR C_SR 370 ${cpl_freq_atm_ctm_sec}  1 r_g2d.nc EXPORTED
  ${atm_grid_nm} ${ctm_grid_sfc} LAG=${lag_atm_ctm_mid}
  P  0  P  0
  SCRIPR
   BILINEAR D SCALAR LATITUDE 90
#enddef

#defcfg ifs tm5:chem # --- Sea ice area fraction ---
  A_CI C_CI 44 ${cpl_freq_atm_ctm_sec}  1 r_g2d.nc EXPORTED
  ${atm_grid_nm} ${ctm_grid_sfc} LAG=${lag_atm_ctm_mid}
  P  0  P  0
  SCRIPR
   BILINEAR D SCALAR LATITUDE 90
#enddef

#defcfg ifs tm5:chem # --- SST ---
  A_SSTChem C_SST 56 ${cpl_freq_atm_ctm_sec}  1 r_g2d.nc EXPORTED
  ${atm_grid_nm} ${ctm_grid_sfc} LAG=${lag_atm_ctm_mid}
  P  0  P  0
  SCRIPR
   BILINEAR D SCALAR LATITUDE 90
#enddef

#defcfg ifs tm5 # --- Wind speed at 10m ---
  A_WSPD C_WSPD 56 ${cpl_freq_atm_ctm_sec}  1 r_g2d.nc EXPORTED
  ${atm_grid_nm} ${ctm_grid_sfc} LAG=${lag_atm_ctm_mid}
  P  0  P  0
  SCRIPR
   BILINEAR D SCALAR LATITUDE 90
#enddef

#defcfg ifs tm5:chem # --- Moisture content of soil layer ---
  A_SRC C_SRC 247 ${cpl_freq_atm_ctm_sec}  1 r_g2d.nc EXPORTED
  ${atm_grid_nm} ${ctm_grid_sfc} LAG=${lag_atm_ctm_mid}
  P  0  P  0
  SCRIPR
   BILINEAR D SCALAR LATITUDE 90
#enddef

#defcfg ifs tm5:chem # --- Dew point temperature ---
  A_D2M C_D2M 160 ${cpl_freq_atm_ctm_sec}  1 r_g2d.nc EXPORTED
  ${atm_grid_nm} ${ctm_grid_sfc} LAG=${lag_atm_ctm_mid}
  P  0  P  0
  SCRIPR
   BILINEAR D SCALAR LATITUDE 90
#enddef

#defcfg ifs tm5:chem # --- Surface temperature ---
  A_T2M C_T2M 34 ${cpl_freq_atm_ctm_sec}  1 r_g2d.nc EXPORTED
  ${atm_grid_nm} ${ctm_grid_sfc} LAG=${lag_atm_ctm_mid}
  P  0  P  0
  SCRIPR
   BILINEAR D SCALAR LATITUDE 90
#enddef

#defcfg ifs tm5 # --- Surface downward latent heat flux ---
  A_SLHF C_SLHF 355 ${cpl_freq_atm_ctm_sec}  2 r_g2d.nc EXPORTED
  ${atm_grid_nm} ${ctm_grid_sfc} LAG=${lag_atm_ctm}
  P  0  P  0
  LOCTRANS SCRIPR
   AVERAGE
   BILINEAR D SCALAR LATITUDE 90
#enddef

#defcfg ifs tm5 # --- Surface downward sensible heat flux ---
  A_SSHF C_SSHF 357 ${cpl_freq_atm_ctm_sec}  2 r_g2d.nc EXPORTED
  ${atm_grid_nm} ${ctm_grid_sfc} LAG=${lag_atm_ctm}
  P  0  P  0
  LOCTRANS SCRIPR
   AVERAGE
   BILINEAR D SCALAR LATITUDE 90
#enddef

#defcfg ifs tm5 # --- surface_downward_grid_eastward_stress ---
  A_EWSS C_EWSS 23 ${cpl_freq_atm_ctm_sec}  2 r_g2d.nc EXPORTED
  ${atm_grid_nm} ${ctm_grid_sfc} LAG=${lag_atm_ctm}
  P  0  P  0
  LOCTRANS SCRIPR
   AVERAGE
   BILINEAR D SCALAR LATITUDE 90
#enddef

#defcfg ifs tm5 # --- surface_downward_grid_northward_stress ---
  A_NSSS C_NSSS 24 ${cpl_freq_atm_ctm_sec}  2 r_g2d.nc EXPORTED
  ${atm_grid_nm} ${ctm_grid_sfc} LAG=${lag_atm_ctm}
  P  0  P  0
  LOCTRANS SCRIPR
   AVERAGE
   BILINEAR D SCALAR LATITUDE 90
#enddef

#defcfg ifs tm5:chem # --- convective_rainfall_flux ---
  A_CP C_CP 154 ${cpl_freq_atm_ctm_sec}  2 r_g2d.nc EXPORTED
  ${atm_grid_nm} ${ctm_grid_sfc} LAG=${lag_atm_ctm}
  P  0  P  0
  LOCTRANS SCRIPR
   AVERAGE
   BILINEAR D SCALAR LATITUDE 90
#enddef

#defcfg ifs tm5:chem # --- large_scale_rainfall_flux ---
  A_LSP C_LSP 212 ${cpl_freq_atm_ctm_sec}  2 r_g2d.nc EXPORTED
  ${atm_grid_nm} ${ctm_grid_sfc} LAG=${lag_atm_ctm}
  P  0  P  0
  LOCTRANS SCRIPR
   AVERAGE
   BILINEAR D SCALAR LATITUDE 90
#enddef

#defcfg ifs tm5:chem # --- surface_net_downward_shortwave_flux ---
  A_SSR C_SSR 7 ${cpl_freq_atm_ctm_sec}  2 r_g2d.nc EXPORTED
  ${atm_grid_nm} ${ctm_grid_sfc} LAG=${lag_atm_ctm}
  P  0  P  0
  LOCTRANS SCRIPR
   AVERAGE
   BILINEAR D SCALAR LATITUDE 90
#enddef

#defcfg ifs tm5:chem # --- surface_snow_amount ---
  A_SD C_SD 373 ${cpl_freq_atm_ctm_sec}  1 r_g2d.nc EXPORTED
  ${atm_grid_nm} ${ctm_grid_sfc} LAG=${lag_atm_ctm_mid}
  P  0  P  0
  SCRIPR
   BILINEAR D SCALAR LATITUDE 90
#enddef

#defcfg ifs tm5:chem # --- Mass fraction of unfrozen water in soil moisture ---
  A_SWVL1 C_SWVL1 242 ${cpl_freq_atm_ctm_sec}  1 r_g2d.nc EXPORTED
  ${atm_grid_nm} ${ctm_grid_sfc} LAG=${lag_atm_ctm_mid}
  P  0  P  0
  SCRIPR
   BILINEAR D SCALAR LATITUDE 90
#enddef

#defcfg ifs tm5:chem # --- Land area fraction ---
  A_TV01 C_TV01 206 ${cpl_freq_atm_ctm_sec}  1 r_g2d.nc EXPORTED
  ${atm_grid_nm} ${ctm_grid_sfc} LAG=${lag_atm_ctm_mid}
  P  0  P  0
  SCRIPR
   BILINEAR D SCALAR LATITUDE 90
#enddef

#defcfg ifs tm5:chem # --- Land area fraction ---
  A_TV02 C_TV02 206 ${cpl_freq_atm_ctm_sec}  1 r_g2d.nc EXPORTED
  ${atm_grid_nm} ${ctm_grid_sfc} LAG=${lag_atm_ctm_mid}
  P  0  P  0
  SCRIPR
   BILINEAR D SCALAR LATITUDE 90
#enddef

#defcfg ifs tm5:chem # --- Land area fraction ---
  A_TV03 C_TV03 206 ${cpl_freq_atm_ctm_sec}  1 r_g2d.nc EXPORTED
  ${atm_grid_nm} ${ctm_grid_sfc} LAG=${lag_atm_ctm_mid}
  P  0  P  0
  SCRIPR
   BILINEAR D SCALAR LATITUDE 90
#enddef

#defcfg ifs tm5:chem # --- Land area fraction ---
  A_TV04 C_TV04 206 ${cpl_freq_atm_ctm_sec}  1 r_g2d.nc EXPORTED
  ${atm_grid_nm} ${ctm_grid_sfc} LAG=${lag_atm_ctm_mid}
  P  0  P  0
  SCRIPR
   BILINEAR D SCALAR LATITUDE 90
#enddef

#defcfg ifs tm5:chem # --- Land area fraction ---
  A_TV05 C_TV05 206 ${cpl_freq_atm_ctm_sec}  1 r_g2d.nc EXPORTED
  ${atm_grid_nm} ${ctm_grid_sfc} LAG=${lag_atm_ctm_mid}
  P  0  P  0
  SCRIPR
   BILINEAR D SCALAR LATITUDE 90
#enddef

#defcfg ifs tm5:chem # --- Land area fraction ---
  A_TV06 C_TV06 206 ${cpl_freq_atm_ctm_sec}  1 r_g2d.nc EXPORTED
  ${atm_grid_nm} ${ctm_grid_sfc} LAG=${lag_atm_ctm_mid}
  P  0  P  0
  SCRIPR
   BILINEAR D SCALAR LATITUDE 90
#enddef

#defcfg ifs tm5:chem # --- Land area fraction ---
  A_TV07 C_TV07 206 ${cpl_freq_atm_ctm_sec}  1 r_g2d.nc EXPORTED
  ${atm_grid_nm} ${ctm_grid_sfc} LAG=${lag_atm_ctm_mid}
  P  0  P  0
  SCRIPR
   BILINEAR D SCALAR LATITUDE 90
#enddef

#defcfg ifs tm5:chem # --- Land area fraction ---
  A_TV09 C_TV09 206 ${cpl_freq_atm_ctm_sec}  1 r_g2d.nc EXPORTED
  ${atm_grid_nm} ${ctm_grid_sfc} LAG=${lag_atm_ctm_mid}
  P  0  P  0
  SCRIPR
   BILINEAR D SCALAR LATITUDE 90
#enddef

#defcfg ifs tm5:chem # --- Land area fraction ---
  A_TV10 C_TV10 206 ${cpl_freq_atm_ctm_sec}  1 r_g2d.nc EXPORTED
  ${atm_grid_nm} ${ctm_grid_sfc} LAG=${lag_atm_ctm_mid}
  P  0  P  0
  SCRIPR
   BILINEAR D SCALAR LATITUDE 90
#enddef

#defcfg ifs tm5:chem # --- Land area fraction ---
  A_TV11 C_TV11 206 ${cpl_freq_atm_ctm_sec}  1 r_g2d.nc EXPORTED
  ${atm_grid_nm} ${ctm_grid_sfc} LAG=${lag_atm_ctm_mid}
  P  0  P  0
  SCRIPR
   BILINEAR D SCALAR LATITUDE 90
#enddef

#defcfg ifs tm5:chem # --- Land area fraction ---
  A_TV13 C_TV13 206 ${cpl_freq_atm_ctm_sec}  1 r_g2d.nc EXPORTED
  ${atm_grid_nm} ${ctm_grid_sfc} LAG=${lag_atm_ctm_mid}
  P  0  P  0
  SCRIPR
   BILINEAR D SCALAR LATITUDE 90
#enddef

#defcfg ifs tm5:chem # --- Land area fraction ---
  A_TV16 C_TV16 206 ${cpl_freq_atm_ctm_sec}  1 r_g2d.nc EXPORTED
  ${atm_grid_nm} ${ctm_grid_sfc} LAG=${lag_atm_ctm_mid}
  P  0  P  0
  SCRIPR
   BILINEAR D SCALAR LATITUDE 90
#enddef

#defcfg ifs tm5:chem # --- Land area fraction ---
  A_TV17 C_TV17 206 ${cpl_freq_atm_ctm_sec}  1 r_g2d.nc EXPORTED
  ${atm_grid_nm} ${ctm_grid_sfc} LAG=${lag_atm_ctm_mid}
  P  0  P  0
  SCRIPR
   BILINEAR D SCALAR LATITUDE 90
#enddef

#defcfg ifs tm5:chem # --- Land area fraction ---
  A_TV18 C_TV18 206 ${cpl_freq_atm_ctm_sec}  1 r_g2d.nc EXPORTED
  ${atm_grid_nm} ${ctm_grid_sfc} LAG=${lag_atm_ctm_mid}
  P  0  P  0
  SCRIPR
   BILINEAR D SCALAR LATITUDE 90
#enddef

#defcfg ifs tm5:chem # --- Land area fraction ---
  A_TV19 C_TV19 206 ${cpl_freq_atm_ctm_sec}  1 r_g2d.nc EXPORTED
  ${atm_grid_nm} ${ctm_grid_sfc} LAG=${lag_atm_ctm_mid}
  P  0  P  0
  SCRIPR
   BILINEAR D SCALAR LATITUDE 90
#enddef

#defcfg ifs tm5:chem # --- Low vegetation area fraction ---
  A_CVL C_CVL 446 ${cpl_freq_atm_ctm_sec}  1 r_g2d.nc EXPORTED
  ${atm_grid_nm} ${ctm_grid_sfc} LAG=${lag_atm_ctm_mid}
  P  0  P  0
  SCRIPR
   BILINEAR D SCALAR LATITUDE 90
#enddef

#defcfg ifs tm5:chem # --- High vegetation area fraction ---
  A_CVH C_CVH 446 ${cpl_freq_atm_ctm_sec}  1 r_g2d.nc EXPORTED
  ${atm_grid_nm} ${ctm_grid_sfc} LAG=${lag_atm_ctm_mid}
  P  0  P  0
  SCRIPR
   BILINEAR D SCALAR LATITUDE 90
#enddef

#defcfg any tm5:o3fb tm5:ch4fb tm5:aerfb
# =================================================================================================
# Fields send from CTM to Atmosphere
# =================================================================================================
#enddef

#defcfg ifs tm5:o3fb # --- Ozone ---
expfield_fbck C_O3 A_O3 244 o3ch4.nc ${lag_ctm_atm} "# --------------- Field 1: Ozone (O3) --------------"
#enddef

#defcfg ifs tm5:ch4fb # --- Methane ---
expfield_fbck C_CH4 A_CH4 244 o3ch4.nc ${lag_ctm_atm} "# --------------- Field 2: Methane (CH4) --------------"
#enddef

#defcfg ifs tm5:co2fb # --- CO2 ---
expfield_fbck_ccycle C_CO2 A_CO2 244 co2mx.nc ${lag_ctm_atm} "# --------------- Field 3: CO2 --------------"
#enddef


#defcfg ifs tm5:aerfb # --- Aerosols concentrations ---
#
# --------------- M7 tracers (25 entries) --------------
#
#expfield_fbck_cutoff C_N1  A_N1  244 C_N1_.nc ${lag_ctm_atm} "# --------------- N1  --------------"
#expfield_fbck_cutoff C_SU1 A_SU1 244 C_SU1.nc ${lag_ctm_atm} "# --------------- SU1 --------------"
expfield_fbck_cutoff C_N2  A_N2  244 C_N2_.nc ${lag_ctm_atm} "# --------------- N2  --------------"
expfield_fbck_cutoff C_SU2 A_SU2 244 C_SU2.nc ${lag_ctm_atm} "# --------------- SU2 --------------"
expfield_fbck_cutoff C_BC2 A_BC2 244 C_BC2.nc ${lag_ctm_atm} "# --------------- BC2 --------------"
expfield_fbck_cutoff C_OC2 A_OM2 244 C_OC2.nc ${lag_ctm_atm} "# --------------- OC2 --------------"
expfield_fbck_cutoff C_N3  A_N3  244 C_N3_.nc ${lag_ctm_atm} "# --------------- N3  --------------"
expfield_fbck_cutoff C_SU3 A_SU3 244 C_SU3.nc ${lag_ctm_atm} "# --------------- SU3 --------------"
expfield_fbck_cutoff C_BC3 A_BC3 244 C_BC3.nc ${lag_ctm_atm} "# --------------- BC3 --------------"
expfield_fbck_cutoff C_OC3 A_OM3 244 C_OC3.nc ${lag_ctm_atm} "# --------------- OC3 --------------"
expfield_fbck_cutoff C_SS3 A_SS3 244 C_SS3.nc ${lag_ctm_atm} "# --------------- SS3 --------------"
expfield_fbck_cutoff C_DU3 A_DD3 244 C_DU3.nc ${lag_ctm_atm} "# --------------- DU3 --------------"
expfield_fbck_cutoff C_N4  A_N4  244 C_N4_.nc ${lag_ctm_atm} "# --------------- N4  --------------"
expfield_fbck_cutoff C_SU4 A_SU4 244 C_SU4.nc ${lag_ctm_atm} "# --------------- SU4 --------------"
expfield_fbck_cutoff C_BC4 A_BC4 244 C_BC4.nc ${lag_ctm_atm} "# --------------- BC4 --------------"
expfield_fbck_cutoff C_OC4 A_OM4 244 C_OC4.nc ${lag_ctm_atm} "# --------------- OC4 --------------"
expfield_fbck_cutoff C_SS4 A_SS4 244 C_SS4.nc ${lag_ctm_atm} "# --------------- SS4 --------------"
expfield_fbck_cutoff C_DU4 A_DD4 244 C_DU4.nc ${lag_ctm_atm} "# --------------- DU4 --------------"
expfield_fbck_cutoff C_N5  A_N5  244 C_N5_.nc ${lag_ctm_atm} "# --------------- N5  --------------"
expfield_fbck_cutoff C_BC5 A_BC5 244 C_BC5.nc ${lag_ctm_atm} "# --------------- BC5 --------------"
expfield_fbck_cutoff C_OC5 A_OM5 244 C_OC5.nc ${lag_ctm_atm} "# --------------- OC5 --------------"
expfield_fbck_cutoff C_N6  A_N6  244 C_N6_.nc ${lag_ctm_atm} "# --------------- N6  --------------"
expfield_fbck_cutoff C_DU6 A_DD6 244 C_DU6.nc ${lag_ctm_atm} "# --------------- DU6 --------------"
expfield_fbck_cutoff C_N7  A_N7  244 C_N7_.nc ${lag_ctm_atm} "# --------------- N7  --------------"
expfield_fbck_cutoff C_DU7 A_DD7 244 C_DU7.nc ${lag_ctm_atm} "# --------------- DU7 --------------"
expfield_fbck_cutoff C_NO3 A_NO3 244 C_NO3.nc ${lag_ctm_atm} "# --------------- NO3 --------------"
expfield_fbck_cutoff C_MSA A_MSA 244 C_MSA.nc ${lag_ctm_atm} "# --------------- MSA --------------"
#
# --------------- AEROSOL OPTICAL PROPERTIES FOR THE 14 WAVELENGTHS --------------
# ---------------  OF THE MCRAD RADIATION SCHEME (14*3 ENTRIES) --------------
#
expfield_fbck_cutoff C_AOD_01  A_AOD_01 244 C_AOD_01 ${lag_ctm_atm} "# ------------- AOD #1 --------------"
expfield_fbck_cutoff C_AOD_02  A_AOD_02 244 C_AOD_02 ${lag_ctm_atm} "# ------------- AOD #2 --------------"
expfield_fbck_cutoff C_AOD_03  A_AOD_03 244 C_AOD_03 ${lag_ctm_atm} "# ------------- AOD #3 --------------"
expfield_fbck_cutoff C_AOD_04  A_AOD_04 244 C_AOD_04 ${lag_ctm_atm} "# ------------- AOD #4 --------------"
expfield_fbck_cutoff C_AOD_05  A_AOD_05 244 C_AOD_05 ${lag_ctm_atm} "# ------------- AOD #5 --------------"
expfield_fbck_cutoff C_AOD_06  A_AOD_06 244 C_AOD_06 ${lag_ctm_atm} "# ------------- AOD #6 --------------"
expfield_fbck_cutoff C_AOD_07  A_AOD_07 244 C_AOD_07 ${lag_ctm_atm} "# ------------- AOD #7 --------------"
expfield_fbck_cutoff C_AOD_08  A_AOD_08 244 C_AOD_08 ${lag_ctm_atm} "# ------------- AOD #8 --------------"
expfield_fbck_cutoff C_AOD_09  A_AOD_09 244 C_AOD_09 ${lag_ctm_atm} "# ------------- AOD #9 --------------"
expfield_fbck_cutoff C_AOD_10  A_AOD_10 244 C_AOD_10 ${lag_ctm_atm} "# ------------- AOD #10 -------------"
expfield_fbck_cutoff C_AOD_11  A_AOD_11 244 C_AOD_11 ${lag_ctm_atm} "# ------------- AOD #11 -------------"
expfield_fbck_cutoff C_AOD_12  A_AOD_12 244 C_AOD_12 ${lag_ctm_atm} "# ------------- AOD #12 -------------"
expfield_fbck_cutoff C_AOD_13  A_AOD_13 244 C_AOD_13 ${lag_ctm_atm} "# ------------- AOD #13 -------------"
expfield_fbck_cutoff C_AOD_14  A_AOD_14 244 C_AOD_14 ${lag_ctm_atm} "# ------------- AOD #14 -------------"
expfield_fbck_cutoff C_SSA_01  A_SSA_01 244 C_SSA_01 ${lag_ctm_atm} "# ----- Single-Scattering Albedo #1 ----"
expfield_fbck_cutoff C_SSA_02  A_SSA_02 244 C_SSA_02 ${lag_ctm_atm} "# ----- Single-Scattering Albedo #2 ----"
expfield_fbck_cutoff C_SSA_03  A_SSA_03 244 C_SSA_03 ${lag_ctm_atm} "# ----- Single-Scattering Albedo #3 ----"
expfield_fbck_cutoff C_SSA_04  A_SSA_04 244 C_SSA_04 ${lag_ctm_atm} "# ----- Single-Scattering Albedo #4 ----"
expfield_fbck_cutoff C_SSA_05  A_SSA_05 244 C_SSA_05 ${lag_ctm_atm} "# ----- Single-Scattering Albedo #5 ----"
expfield_fbck_cutoff C_SSA_06  A_SSA_06 244 C_SSA_06 ${lag_ctm_atm} "# ----- Single-Scattering Albedo #6 ----"
expfield_fbck_cutoff C_SSA_07  A_SSA_07 244 C_SSA_07 ${lag_ctm_atm} "# ----- Single-Scattering Albedo #7 ----"
expfield_fbck_cutoff C_SSA_08  A_SSA_08 244 C_SSA_08 ${lag_ctm_atm} "# ----- Single-Scattering Albedo #8 ----"
expfield_fbck_cutoff C_SSA_09  A_SSA_09 244 C_SSA_09 ${lag_ctm_atm} "# ----- Single-Scattering Albedo #9 ----"
expfield_fbck_cutoff C_SSA_10  A_SSA_10 244 C_SSA_10 ${lag_ctm_atm} "# ----- Single-Scattering Albedo #10 ---"
expfield_fbck_cutoff C_SSA_11  A_SSA_11 244 C_SSA_11 ${lag_ctm_atm} "# ----- Single-Scattering Albedo #11 ---"
expfield_fbck_cutoff C_SSA_12  A_SSA_12 244 C_SSA_12 ${lag_ctm_atm} "# ----- Single-Scattering Albedo #12 ---"
expfield_fbck_cutoff C_SSA_13  A_SSA_13 244 C_SSA_13 ${lag_ctm_atm} "# ----- Single-Scattering Albedo #13 ---"
expfield_fbck_cutoff C_SSA_14  A_SSA_14 244 C_SSA_14 ${lag_ctm_atm} "# ----- Single-Scattering Albedo #14 ---"
expfield_fbck_cutoff C_ASF_01  A_ASF_01 244 C_ASF_01 ${lag_ctm_atm} "# --------- Asymmetry Factor #1 --------"
expfield_fbck_cutoff C_ASF_02  A_ASF_02 244 C_ASF_02 ${lag_ctm_atm} "# --------- Asymmetry Factor #2 --------"
expfield_fbck_cutoff C_ASF_03  A_ASF_03 244 C_ASF_03 ${lag_ctm_atm} "# --------- Asymmetry Factor #3 --------"
expfield_fbck_cutoff C_ASF_04  A_ASF_04 244 C_ASF_04 ${lag_ctm_atm} "# --------- Asymmetry Factor #4 --------"
expfield_fbck_cutoff C_ASF_05  A_ASF_05 244 C_ASF_05 ${lag_ctm_atm} "# --------- Asymmetry Factor #5 --------"
expfield_fbck_cutoff C_ASF_06  A_ASF_06 244 C_ASF_06 ${lag_ctm_atm} "# --------- Asymmetry Factor #6 --------"
expfield_fbck_cutoff C_ASF_07  A_ASF_07 244 C_ASF_07 ${lag_ctm_atm} "# --------- Asymmetry Factor #7 --------"
expfield_fbck_cutoff C_ASF_08  A_ASF_08 244 C_ASF_08 ${lag_ctm_atm} "# --------- Asymmetry Factor #8 --------"
expfield_fbck_cutoff C_ASF_09  A_ASF_09 244 C_ASF_09 ${lag_ctm_atm} "# --------- Asymmetry Factor #9 --------"
expfield_fbck_cutoff C_ASF_10  A_ASF_10 244 C_ASF_10 ${lag_ctm_atm} "# --------- Asymmetry Factor #10 -------"
expfield_fbck_cutoff C_ASF_11  A_ASF_11 244 C_ASF_11 ${lag_ctm_atm} "# --------- Asymmetry Factor #11 -------"
expfield_fbck_cutoff C_ASF_12  A_ASF_12 244 C_ASF_12 ${lag_ctm_atm} "# --------- Asymmetry Factor #12 -------"
expfield_fbck_cutoff C_ASF_13  A_ASF_13 244 C_ASF_13 ${lag_ctm_atm} "# --------- Asymmetry Factor #13 -------"
expfield_fbck_cutoff C_ASF_14  A_ASF_14 244 C_ASF_14 ${lag_ctm_atm} "# --------- Asymmetry Factor #14 -------"
#enddef

#defcfg atm lpjg
# ====================================================================
# Fields send from Atmosphere to LPJ-GUESS
# ====================================================================
#enddef

#defcfg atm lpjg # --- '2m_temperature' 'K' --
  T2MVeg T2M_LPJG 1 ${cpl_freq_atm_lpjg_sec} 1 vegin.nc EXPORTED
  ${atm_grid} ${lpjg_grid} LAG=${lag_atm_lpjg}
  P 0 P 0
  LOCTRANS
   AVERAGE
#enddef

#defcfg atm lpjg # --- 'Total precip' 'm_timestep-1' ---
  TPVeg TPRE_LPJ 1 ${cpl_freq_atm_lpjg_sec} 1 vegin.nc EXPORTED
  ${atm_grid} ${lpjg_grid} LAG=${lag_atm_lpjg}
  P 0 P 0
  LOCTRANS
   AVERAGE
#enddef

#defcfg atm lpjg  # --- 'Mass snow' 'kg_m-2' ---
  SDVeg SNOC_LPJ 1 ${cpl_freq_atm_lpjg_sec} 1 vegin.nc EXPORTED
  ${atm_grid} ${lpjg_grid} LAG=${lag_atm_lpjg}
  P 0 P 0
  LOCTRANS
   AVERAGE
#enddef

#defcfg atm lpjg  # --- 'Density snow' 'kg_m-3' ---
  SDensVeg SNOD_LPJ 1 ${cpl_freq_atm_lpjg_sec} 1 vegin.nc EXPORTED
  ${atm_grid} ${lpjg_grid} LAG=${lag_atm_lpjg}
  P 0 P 0
  LOCTRANS
   AVERAGE
#enddef

#defcfg atm lpjg  # --- 'Soil T lay1' 'K' ---
  SoilTVeg.L001 ST1L_LPJ 1 ${cpl_freq_atm_lpjg_sec} 1 vegin.nc EXPORTED
  ${atm_grid} ${lpjg_grid} LAG=${lag_atm_lpjg}
  P 0 P 0
  LOCTRANS
   AVERAGE
#enddef

#defcfg atm lpjg  # --- 'Soil T lay2' 'K' ---
  SoilTVeg.L002 ST2L_LPJ 1 ${cpl_freq_atm_lpjg_sec} 1 vegin.nc EXPORTED
  ${atm_grid} ${lpjg_grid} LAG=${lag_atm_lpjg}
  P 0 P 0
  LOCTRANS
   AVERAGE
#enddef

#defcfg atm lpjg # --- 'Soil T lay3' 'K' ---
  SoilTVeg.L003 ST3L_LPJ 1 ${cpl_freq_atm_lpjg_sec} 1 vegin.nc EXPORTED
  ${atm_grid} ${lpjg_grid} LAG=${lag_atm_lpjg}
  P 0 P 0
  LOCTRANS
   AVERAGE
#enddef

#defcfg atm lpjg  # --- 'Soil T lay4' 'K' ---
  SoilTVeg.L004 ST4L_LPJ 1 ${cpl_freq_atm_lpjg_sec} 1 vegin.nc EXPORTED
  ${atm_grid} ${lpjg_grid} LAG=${lag_atm_lpjg}
  P 0 P 0
  LOCTRANS
   AVERAGE
#enddef

#defcfg atm lpjg  # --- 'Soil M lay1' 'm3_m-3' ---
  SoilMVeg.L001 SM1L_LPJ 1 ${cpl_freq_atm_lpjg_sec} 1 vegin.nc EXPORTED
  ${atm_grid} ${lpjg_grid} LAG=${lag_atm_lpjg}
  P 0 P 0
  LOCTRANS
   AVERAGE
#enddef

#defcfg atm lpjg  # --- 'Soil M lay2' 'm3_m-3' ---
  SoilMVeg.L002 SM2L_LPJ 1 ${cpl_freq_atm_lpjg_sec} 1 vegin.nc EXPORTED
  ${atm_grid} ${lpjg_grid} LAG=${lag_atm_lpjg}
  P 0 P 0
  LOCTRANS
   AVERAGE
#enddef

#defcfg atm lpjg  # --- 'Soil M lay3' 'm3_m-3' ---
  SoilMVeg.L003 SM3L_LPJ 1 ${cpl_freq_atm_lpjg_sec} 1 vegin.nc EXPORTED
  ${atm_grid} ${lpjg_grid} LAG=${lag_atm_lpjg}
  P 0 P 0
  LOCTRANS
   AVERAGE
#enddef

#defcfg atm lpjg  # --- 'Soil M lay4' 'm3_m-3' ---
  SoilMVeg.L004 SM4L_LPJ 1 ${cpl_freq_atm_lpjg_sec} 1 vegin.nc EXPORTED
  ${atm_grid} ${lpjg_grid} LAG=${lag_atm_lpjg}
  P 0 P 0
  LOCTRANS
   AVERAGE
#enddef

#defcfg atm lpjg  # --- 'surf sol SW rad' 'J_m-2' ---
  SSRVeg SWNR_LPJ 1 ${cpl_freq_atm_lpjg_sec} 1 vegin.nc EXPORTED
  ${atm_grid} ${lpjg_grid} LAG=${lag_atm_lpjg}
  P 0 P 0
  LOCTRANS
   AVERAGE
#enddef

#defcfg atm lpjg  # --- 'surf LW rad' 'J_m-2' ---
  SLRVeg LWNR_LPJ 1 ${cpl_freq_atm_lpjg_sec} 1 vegin.nc EXPORTED
  ${atm_grid} ${lpjg_grid} LAG=${lag_atm_lpjg}
  P 0 P 0
  LOCTRANS
   AVERAGE
#enddef


#defcfg lpjg atm
# ====================================================================
# Fields send from LPJ-GUESS to Atmosphere
# ====================================================================
#enddef


#defcfg atm lpjg  # --- 'low_LAI' 'm2_m-2' ---
  GUE_LLAI LAILVeg 1 ${cpl_freq_atm_lpjg_sec} 1 lpjgv.nc EXPORTED
  ${lpjg_grid} ${atm_grid} LAG=${lag_lpjg_atm}
  P 0 P 0
  LOCTRANS
   INSTANT
#enddef

#defcfg atm lpjg  # --- 'high_LAI' 'm2 m-2' ---
  GUE_HLAI LAIHVeg 1 ${cpl_freq_atm_lpjg_sec} 1 lpjgv.nc EXPORTED
  ${lpjg_grid} ${atm_grid} LAG=${lag_lpjg_atm}
  P 0 P 0
  LOCTRANS
   INSTANT
#enddef

#defcfg atm lpjg  # --- 'High Veg Type' '1-20' ---
  GUE_TYPH TypeHVeg 1 ${cpl_freq_atm_lpjg_sec} 1 lpjgv.nc EXPORTED
  ${lpjg_grid} ${atm_grid} LAG=${lag_lpjg_atm}
  P 0 P 0
  LOCTRANS
   INSTANT
#enddef

#defcfg atm lpjg  # --- 'LPJG High Veg Frac' '0-1' ---
  GUE_FRAH FracHVeg 1 ${cpl_freq_atm_lpjg_sec} 1 lpjgv.nc EXPORTED
  ${lpjg_grid} ${atm_grid} LAG=${lag_lpjg_atm}
  P 0 P 0
  LOCTRANS
   INSTANT
#enddef

#defcfg atm lpjg  # --- 'Low Veg Type' '1-20' ---
  GUE_TYPL TypeLVeg 1 ${cpl_freq_atm_lpjg_sec} 1 lpjgv.nc EXPORTED
  ${lpjg_grid} ${atm_grid} LAG=${lag_lpjg_atm}
  P 0 P 0
  LOCTRANS
   INSTANT
#enddef

#defcfg atm lpjg  # --- 'LPJG Low Veg Frac' '0-1' ---
  GUE_FRAL FracLVeg 1 ${cpl_freq_atm_lpjg_sec} 1 lpjgv.nc EXPORTED
  ${lpjg_grid} ${atm_grid} LAG=${lag_lpjg_atm}
  P 0 P 0
  LOCTRANS
   INSTANT
#enddef


#defcfg ifs amip
# =================================================================================================
# Fields send from AMIP to IFS
# =================================================================================================
#enddef

#defcfg ifs amip # --- AMIP forcing data ---
  AMIP_sst:AMIP_sic A_SST:A_Ice_frac 1 ${cpl_freq_amip_sec} 1 rstas.nc EXPORTED
  AMIP ${atm_grid/A/L} LAG=0
  P  0  P  0
  SCRIPR
   GAUSWGT LR SCALAR LATITUDE 1 9 2.0
#enddef

#defcfg lpjg tm5:co2
# ====================================================================
# Fields send from TM5-MP to LPJ-GUESS
# ====================================================================
#enddef

#defcfg lpjg tm5:co2 # --- atmospheric CO2 concentrations (ppm - daily average/gridcell) ---
  LCO2_TM5 CO2_LPJG 1 ${cpl_freq_ccycle_sec}  1 l_co2.nc EXPORTED
  ${ctm_grid} ${atm_grid/A/B} LAG=${lag_ctm_atm}
  P  0  P  0
  SCRIPR
   BILINEAR LR SCALAR LATITUDE 1
#enddef

#defcfg lpjg tm5:co2
# ====================================================================
# Fields send from LPJ-GUESS to TM5-MP
# ====================================================================
#enddef

#defcfg lpjg tm5 # --- C fluxes (kg carbon/m2/d) ---
  GUE_CNAT:GUE_CANT:GUE_CNPP TM5_LandCNAT:TM5_LandCANT:TM5_LandCNPP 1 ${cpl_freq_ccycle_sec}  2 rlpjg.nc ${ccycle_out_fluxes}
  ${atm_grid/A/B} ${ctm_grid} LAG=${lag_lpjg_atm}
  P  0  P  0
  SCRIPR CONSERV
   GAUSWGT D SCALAR LATITUDE 1 9 2.0
   GLBPOS
#enddef

#defcfg pisces tm5:co2
# ====================================================================
# Fields send from TM5-MP to PISCES.
#  - temporal interpolation: inst or daily mean?
# ====================================================================
#enddef

#defcfg pisces tm5:co2 # --- atmospheric CO2 concentrations (ppm) ---
  OCO2_TM5 O_AtmCO2 1 ${cpl_freq_ccycle_sec}  1 o_co2.nc EXPORTED
  ${ctm_grid/C/L} ${oce_grid} LAG=${lag_ctm_atm}
  P  0  P  2
  SCRIPR
   GAUSWGT LR SCALAR LATITUDE 1 9 2.0
#enddef

#defcfg pisces tm5:co2
# ====================================================================
# Fields send from PISCES to TM5-MP
# ====================================================================
#enddef

#defcfg pisces tm5 # --- C fluxes (molC/m2/s) ---
  O_CO2FLX TM5_OceCFLX 1 ${cpl_freq_ccycle_sec}  3 pisce.nc ${ccycle_out_fluxes}
  ${oce_grid} ${ctm_grid/C/L} LAG=${lag_oce_atm}
  P  2  P  0
  LOCTRANS SCRIPR CONSERV
   AVERAGE
   GAUSWGT LR SCALAR LATITUDE 1 9 2.0
   GLOBAL
#enddef

# -------------------------------------------------------------------------------------------------
 \$END
# =================================================================================================
END_OF_NAMCOUPLE
set -u
