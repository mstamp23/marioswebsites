#!/bin/bash

# --- 1. CONFIG ---
SAVE_DIR="$HOME/Pictures/Banking"
DATE_STAMP=$(date +%d-%m-%Y)
TEMP_PNG="/tmp/bank_capture.png"
mkdir -p "$SAVE_DIR"

# --- 2. CAPTURE ---
xfce4-screenshooter -r -s "$TEMP_PNG"
if [ ! -f "$TEMP_PNG" ]; then exit 1; fi

# --- 3. FIRST MENU: MAIN CATEGORY ---
CAT=$(zenity --list --radiolist --title="1. Κεντρική Κατηγορία" --width=400 --height=500 \
    --column="Επιλογή" --column="Κατηγορία" \
    TRUE "ΕΦΚΑ" \
    FALSE "Ενοίκιο Αλκιβιάδου" \
    FALSE "Κοινόχρηστα Βάρκιζα" \
    FALSE "Τηλέφωνο" \
    FALSE "Φόρος" \
    FALSE "ΕΝΦΙΑ" \
    FALSE "Άλλο")

if [ $? -ne 0 ]; then rm "$TEMP_PNG"; exit 1; fi

# --- 4. CONDITIONAL LOGIC PATHS ---

case "$CAT" in
    "ΕΦΚΑ")
        SUB=$(zenity --list --radiolist --title="Επιλογή Ονόματος ΕΦΚΑ" --width=350 --height=300 \
            --column="Επιλογή" --column="Όνομα" \
            TRUE "Μάριος" \
            FALSE "Κυριάκος")
        if [ $? -ne 0 ]; then rm "$TEMP_PNG"; exit 1; fi
        
        INFO=$(zenity --forms --title="Περίοδος ΕΦΚΑ" --text="Επιλέξτε Μήνα και Έτος για $SUB" \
            --add-combo="Μήνας" --combo-values="01|02|03|04|05|06|07|08|09|10|11|12" \
            --add-combo="Έτος" --combo-values="2026|2027|2028|2029|2030" \
            --separator="-")
        if [ $? -ne 0 ]; then rm "$TEMP_PNG"; exit 1; fi
        
        FINAL_PREFIX="${CAT}_${SUB}_${INFO}"
        DISPLAY_NAME="${CAT} ${SUB} ${INFO}"
        ;;

    "Φόρος" | "ΕΝΦΙΑ")
        SUB=$(zenity --list --radiolist --title="Επιλογή Ονόματος" --width=350 --height=350 \
            --column="Επιλογή" --column="Όνομα" \
            TRUE "Μάριος" \
            FALSE "Κυριάκος" \
            FALSE "Παναγιώτης" \
            FALSE "Αφροδίτη")
        if [ $? -ne 0 ]; then rm "$TEMP_PNG"; exit 1; fi
        FINAL_PREFIX="${CAT}_${SUB}"
        DISPLAY_NAME="${CAT} ${SUB}"
        ;;

    "Ενοίκιο Αλκιβιάδου" | "Κοινόχρηστα Βάρκιζα")
        INFO=$(zenity --forms --title="Επιλογή Περιόδου" --text="Επιλέξτε Μήνα και Έτος για $CAT" \
            --add-combo="Μήνας" --combo-values="01|02|03|04|05|06|07|08|09|10|11|12" \
            --add-combo="Έτος" --combo-values="2026|2027|2028|2029|2030" \
            --separator="-")
        if [ $? -ne 0 ]; then rm "$TEMP_PNG"; exit 1; fi
        FINAL_PREFIX="${CAT}_${INFO}"
        DISPLAY_NAME="${CAT} ${INFO}"
        ;;

    "Τηλέφωνο")
        # Ενημερωμένη λίστα με "Χωριό"
        SUB=$(zenity --list --radiolist --title="Επιλογή Γραμμής" --width=350 --height=350 \
            --column="Επιλογή" --column="Τοποθεσία" \
            TRUE "Ελευθερίας" \
            FALSE "Αλκιβιάδου" \
            FALSE "Χωριό")
        if [ $? -ne 0 ]; then rm "$TEMP_PNG"; exit 1; fi
        FINAL_PREFIX="${CAT}_${SUB}"
        DISPLAY_NAME="${CAT} ${SUB}"
        ;;

    "Άλλο")
        SUB=$(zenity --entry --title="Περιγραφή" --text="Τι πληρώσατε;")
        if [ -z "$SUB" ]; then SUB="Αλλο"; fi
        FINAL_PREFIX="$SUB"
        DISPLAY_NAME="$SUB"
        ;;
esac

# --- 5. AMOUNT ENTRY ---
AMOUNT=$(zenity --entry --title="Ποσό Πληρωμής" --text="Εισάγετε το ποσό για: $DISPLAY_NAME")
if [ -z "$AMOUNT" ]; then AMOUNT="0"; fi

# --- 6. SAVE AS JPG ---
FINAL_NAME="${FINAL_PREFIX} ,${DATE_STAMP},${AMOUNT}.jpg"
convert "$TEMP_PNG" "$SAVE_DIR/$FINAL_NAME"

# --- 7. CLEANUP ---
rm "$TEMP_PNG"
notify-send "Banking Sync" "Αποθηκεύτηκε: $FINAL_NAME"
