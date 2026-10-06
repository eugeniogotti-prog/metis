#!/bin/bash
# con-timeout.sh SECONDI comando [argomenti…] — sostituto di `timeout`, che su macOS non esiste.
# Esce con il codice del comando, oppure 142 (SIGALRM) se scade il tempo. Perl è nel sistema base di macOS.
# Portato il 6/10/2026 dal vault di riferimento, dove un giro automatico ha usato `timeout`, ha ricevuto
# «command not found» e ha letto l'uscita vuota come un risultato.
[ $# -ge 2 ] || { echo "uso: con-timeout.sh SECONDI comando [argomenti…]" >&2; exit 2; }
s=$1; shift
exec perl -e 'alarm shift; exec @ARGV or die "con-timeout: $ARGV[0]: $!\n"' "$s" "$@"
