##########################################################################################
#
# Magisk Module Installer Script
#
##########################################################################################

profile_convert() {
  ui_print " "
  ui_print "- Converting old profiles to new format..."
  [ -d /storage/emulated/0/ViPER4Android ] && FOL=/storage/emulated/0/ViPER4Android || FOL=$(find /storage -type d -name "ViPER4Android" 2>/dev/null | head -n1)
  [ -z $FOL ] && FOL=$(find /data/media -type d -name "ViPER4Android" 2>/dev/null | head -n1)
  [ -z $FOL ] && FOL=$(find /sdcard -type d -name "ViPER4Android" 2>/dev/null | head -n1)
  [ -z $FOL ] && FOL=/storage/emulated/0/ViPER4Android
  [ "$(ls -A $FOL/Profile 2>/dev/null)" ] || { ui_print "- No old profiles found, nothing to convert"; return; }
  
  ui_print "   ViPER4Android folder detected at: $FOL!"
  ui_print "   If new preset already exists, it will be skipped"
  ui_print " "
  
  [ "$(ls -A $FOL/Profile 2>/dev/null)" ] || { ui_print "No profiles detected!"; exit 1; }
  mkdir -p $FOL/Preset 2>/dev/null
  . $TMPDIR/keys.sh

  find $FOL/Profile -mindepth 1 -maxdepth 1 -type d 2>/dev/null | while read PROFILE; do
    ui_print "   Converting $(basename "$PROFILE")"
    for DEVICE in bluetooth headset speaker usb; do
      case $DEVICE in
        bluetooth) DEST="$FOL/Preset/$(basename "$PROFILE")-$DEVICE/bt_a2dp.xml";;
        headset) DEST="$FOL/Preset/$(basename "$PROFILE")-$DEVICE/headset.xml";;
        speaker) DEST="$FOL/Preset/$(basename "$PROFILE")-$DEVICE/speaker.xml";;
        usb) DEST="$FOL/Preset/$(basename "$PROFILE")-$DEVICE/usb_device.xml";;
      esac
      for FORMAT in txt xml; do
        if [ "$FORMAT" == "xml" ]; then
          SOURCE="$PROFILE/com.vipercn.viper4android_v2.$DEVICE.xml"
          DEST="$(echo "$DEST" | sed "s|-$DEVICE|-$DEVICE-Legacy|")"
          [ -f "$SOURCE" ] || continue
          [ -d "$(dirname "$DEST")" ] && { ui_print "     New $(basename $DEVICE) preset already exists! Skipping..."; continue; }
          [ "$(head -n1 "$SOURCE")" == "<?xml version='1.0' encoding='utf-8' standalone='yes' ?>" ] || { ui_print "     $(basename "$PROFILE") $(basename $DEVICE) profile bugged! Skipping!"; continue; }
        else
          SOURCE="$PROFILE/$DEVICE.txt"
          [ -f "$SOURCE" ] || continue
          [ -d "$(dirname "$DEST")" ] && { ui_print "     New $(basename $DEVICE) preset already exists! Skipping..."; continue; }
          [ "$(head -n1 "$SOURCE")" == "<?xml version='1.0' encoding='utf-8' standalone='yes' ?>" ] && { ui_print "     $(basename "$PROFILE") $(basename $DEVICE) profile bugged! Skipping!"; continue; }
        fi
        [ "$FORMAT" == "xml" ] && ui_print "     Creating new $DEVICE-legacy profile..." || ui_print "     Creating new $DEVICE profile..."
        mkdir "$(dirname "$DEST")" 2>/dev/null
        cp -f $TMPDIR/$(basename "$DEST") "$DEST"
        while read LINE; do
          [ "$(echo "$LINE" | grep 'ddcblock')" ] && continue # Skip ddcblock lines - not used and just slow down script
          if [ "$FORMAT" == "xml" ]; then
            case "$LINE" in
              *"string name="*) VALUE="$(echo "$LINE" | sed -r -e "s|.*>(.*)</.*|\1|" -e "s/FILE://")"; LINE="$(echo "$LINE" | sed -r -e "s|.*name=\"viper4android.[A-Za-z]*\.(.*)\".*|\1|" -e "s/viperddc/ddc/" -e "s/\./_/g")";;
              *"boolean name="*) VALUE="$(echo "$LINE" | sed -r "s|.*value=\"(.*)\" />.*|\1|")"; LINE="$(echo "$LINE" | sed -r -e "s|.*name=\"viper4android.[A-Za-z]*\.(.*)\" v.*|\1|" -e "s/viperddc/ddc/" -e "s/\./_/g")";;
              *) continue;;
            esac
            # Change speaker entry names
            [ "$DEVICE" == "speaker" ]&& { case "$LINE" in
                                             convolver*|fet*|fireq*|limiter|outvol|playback*|reverb*) LINE="speaker_$LINE";;
                                           esac; }
            # Change dynamicsystem_bass
            [ "$LINE" == "dynamicsystem_bass" ] && VALUE=$((VALUE * 20 + 100))
          else
            case "$LINE" in
              [A-Z-a-z.]*) VALUE="$(echo "$LINE" | sed -e "s|^.*=||" -e "s/FILE://")"; LINE="$(echo "$LINE" | sed -e "s|=.*$||" -e "s/viperddc/ddc/" -e "s/\./_/g")";;
              *) continue;;
            esac
            # Change speaker entry names
            [ "$DEVICE" == "speaker" -a "$LINE" == "speaker_enable" ] && LINE=enable
            # Change vse value
            [ "$LINE" == "vse_value" ] && { VALUE="$(echo $VALUE | sed "s/;.*//")"; VALUE=$(awk -v VALUE=$VALUE 'BEGIN{VALUE=(VALUE/5.6); print VALUE;}'); }
          fi
          # Change names
          case "$LINE" in
            *fireq) continue;;
            *fireq_custom) LINE="$(echo $LINE | sed "s/_custom//")";;
            dynamicsystem_coeffs) LINE=dynamicsystem_device;;
            dynamicsystem_bass) LINE=dynamicsystem_strength;;
            tube_enable) LINE=tube_simulator_enable;;
            channelpan) LINE=gate_channelpan;;
            *limiter) LINE=gate_limiter;;
            *outvol) LINE=gate_outputvolume;;
            *reverb*) LINE="$(echo $LINE | sed -e "s/reverb_/reverberation_/" -e "s/roomwidth/room_width/")";;
            *fetcompressor*) LINE="$(echo $LINE | sed "s|fetcompressor_|fet_|")";;
            vhs_qual) LINE=vhs_quality;;
            fidelity_bass_freq) LINE=fidelity_bass_frequency;;
            spkopt_enable|speaker_optimize) LINE=speaker_optimization;;
          esac
          case "$LINE" in
            fidelity_bass_mode|fidelity_clarity_mode|ddc_device|*fireq|*convolver_kernel|dynamicsystem_device)
              VALUE="$(basename "$VALUE")"
              [ "$LINE" == "ddc_device" -o "$LINE" == "convolver_kernel" ] && [ "$VALUE" ] && [ $VALUE -eq $VALUE ] 2>/dev/null && VALUE="$(grep "$VALUE" $TMPDIR/VDCIndex.txt | sed -r "s/^[0-9]*=\"(.*)\"/\1/").vdc"
              LINE="$(eval echo \$$LINE)"
              sed -i "/$LINE/ s|>.*</string>|>$VALUE</string>|" "$DEST";;
            *) LINE="$(eval echo \$$LINE)"
               if [ -z $LINE ]; then
                 continue
               else  
                 # Convert to integer
                 case "$VALUE" in
                   [0-9]*.[0-9]*) VALUE=$(awk -v VALUE=$VALUE 'BEGIN{VALUE=(VALUE*100); print VALUE;}');;
                   [0-9]*\;[0-9]*) VALUE="$(echo $VALUE | sed "s/;.*//")";; #colorfulmusic_coeffs
                 esac
                 # Round to Tenth place due to profile saving bug in original v4a
                 case "$LINE" in
                   *reverberation_room*) VALUE=$(awk -v VALUE=$VALUE 'BEGIN{VALUE = sprintf("%1.0e\n",VALUE); printf "%d\n", VALUE}');;
                 esac
                 sed -i "/$LINE/ s|value=\".*\"|value=\"$VALUE\"|" "$DEST"
               fi;;
          esac
        done < "$SOURCE"
      done
    done
  done
}

SKIPUNZIP=1
$BOOTMODE || abort "! This is for magisk manager only!"
[ "`getenforce`" == "Enforcing" ] && ENFORCE=true || ENFORCE=false
unzip -oj "$ZIPFILE" 'common/*' -d $TMPDIR >&2
chmod 0755 $TMPDIR/curl-$ARCH32

# Uninstall existing v4a installs
REMS=$(find /data/app -type d -name "*com.pittvandewitt.viperfx*" -o -name "*com.audlabs.viperfx*" -o -name "*com.vipercn.viper4android_v2*")
if [ "$REMS" ]; then
  ui_print "- Removing old v4a app installs..."
  for i in ${REMS}; do
    case $i in
      *com.pittvandewitt.viperfx*) pm uninstall com.pittvandewitt.viperfx >/dev/null 2>&1;;
      *com.audlabs.viperfx*) pm uninstall com.audlabs.viperfx >/dev/null 2>&1;;
      *com.vipercn.viper4android*) pm uninstall com.vipercn.viper4android_v2 >/dev/null 2>&1;;
    esac
  done
fi
# Remove remnants of any old v4a installs
for REMS in $(find /data/data -name "*ViPER4AndroidFX*" -o -name "*com.audlabs.viperfx*" -o -name "*com.vipercn.viper4android_v2*"); do
  if [ -d "$REMS" ]; then
    rm -rf $REMS
  else
    rm -f $REMS
  fi
done
  
# Tell user aml is needed if applicable
AML=false
[ -d $NVBASE/modules/aml -o -d $MODULEROOT/aml ] || for i in $(find $NVBASE/modules/*/system $MODULEROOT/*/system -type f -name "*audio_effects*.conf" -o -name "*audio_effects*.xml" 2>/dev/null); do
  [ -f $(echo "$i" | sed "s|/system/.*|/|")remove ] || { AML=true; break; }
done
if $AML; then
  ui_print " "
  ui_print "   ! Conflicting audio mod found!"
  ui_print "   ! You will need to install !"
  ui_print "   ! Audio Modification Library !"
  sleep 3
fi

ui_print " "
ui_print "- Downloading latest apk..."
# URL needs changed to real server
($TMPDIR/curl-$ARCH32 -o $TMPDIR/v4afx.apk https://zackptg5.com/downloads/v4afx.apk) || abort "   Download failed! Connect to internet and try again"
ui_print "- Installing ViPER4AndroidFX v2.7.1..."
$ENFORCE && setenforce 0
(pm install $TMPDIR/v4afx.apk >/dev/null 2>&1) || ui_print "   V4AFX install failed! Install $FOL/v4afx.apk manually"
$ENFORCE && setenforce 1

# Install temporary service script
cp -f $TMPDIR/service.sh $NVBASE/service.d/v4afx.sh
chmod 0755 $NVBASE/service.d/v4afx.sh

# Convert old profiles to new presets
profile_convert

ui_print " "
ui_print "- Copying original V4A vdcs to:"
ui_print "  $FOL/DDC-Orig..." 
ui_print "   Copy the ones you want to the DDC folder"
ui_print " "
ui_print "   Note that some of these aren't that great"
ui_print "   Check out here for better ones:"
ui_print "   https://t.me/vdcservice"
ui_print " "
mkdir -p $FOL/DDC-Orig 2>/dev/null
unzip -oj $TMPDIR/vdcs.zip -d $FOL/DDC-Orig >&2
cp -f $TMPDIR/v4afx.apk $FOL/v4afx.apk

ui_print "   After this completes,"
ui_print "   open V4A app and follow the prompts"
ui_print " "
sleep 5

REMS=$(find $NVBASE/modules/*/system $MODULEROOT/*/system -type f -name "ViPER4AndroidFX.apk" 2>/dev/null)
if [ "$REMS" ]; then
  ui_print "- Marking all old v4a modules for deletion..."
  for i in ${REMS}; do
    i="$(echo "$i" | sed "s|/system/.*|/|")"
    touch $i/remove
  done
fi
rm -rf $MODPATH $NVBASE/modules/$MODID 2>/dev/null
