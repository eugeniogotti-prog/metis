#!/usr/bin/env python3
"""scorciatoia.py — prepara, sul Mac di chi assiste il cliente, la Scorciatoia iPhone «Manda riunione» già pronta e firmata.

La Scorciatoia compare in Condividi (per esempio da Memo vocali) e manda l'audio con un POST HTTPS all'ingresso delle
riunioni del server del cliente (scripts/server/riunioni.py), con il segreto nell'intestazione X-Metis-Segreto.
Il file si manda al cliente (AirDrop, mail a se stesso, iCloud): un tocco e la Scorciatoia è installata, senza
ricostruirla a mano (docs/scorciatoia-riunioni.md).

Uso (solo macOS, serve il comando «shortcuts»):
  scorciatoia.py --url https://<nome del server>/riunione --segreto <file con il segreto> [--uscita <cartella>] [--nome "Manda riunione"]
Il segreto si legge da un file (mai dalla riga di comando). La copia non firmata, che lo contiene in chiaro, si cancella
subito dopo la firma; il file firmato lo contiene ancora: va trattato come una chiave e mandato solo al cliente.
Firma «anyone»: la Scorciatoia si installa su qualsiasi iPhone (provato il 10/11/2026 con una riunione di 47 minuti).
"""
import argparse, os, plistlib, shutil, subprocess, sys, tempfile, uuid


def testo(s):
    return {"Value": {"string": s, "attachmentsByRange": {}}, "WFSerializationType": "WFTextTokenString"}


def flusso(url, segreto):
    uid = str(uuid.uuid4()).upper()
    # La notifica mostra la risposta del server («Ricevuta…», oppure il motivo del rifiuto), non un testo fisso.
    risposta = {"Value": {"string": "\ufffc", "attachmentsByRange": {"{0, 1}": {
        "OutputUUID": uid, "Type": "ActionOutput", "OutputName": "Contenuto dell'URL"}}},
        "WFSerializationType": "WFTextTokenString"}
    intestazioni = {"Value": {"WFDictionaryFieldValueItems": [
        {"WFItemType": 0, "WFKey": testo("X-Metis-Segreto"), "WFValue": testo(segreto)}]},
        "WFSerializationType": "WFDictionaryFieldValue"}
    return {
        "WFWorkflowMinimumClientVersion": 900, "WFWorkflowMinimumClientVersionString": "900",
        "WFWorkflowClientVersion": "2605.0.5",
        "WFWorkflowIcon": {"WFWorkflowIconStartColor": 4282601983, "WFWorkflowIconGlyphNumber": 59511},
        "WFWorkflowTypes": ["ActionExtension"],   # compare in Condividi
        "WFWorkflowInputContentItemClasses": ["WFAVAssetContentItem", "WFGenericFileContentItem"],
        "WFWorkflowHasShortcutInputVariables": True,
        "WFWorkflowImportQuestions": [],
        "WFWorkflowActions": [
            {"WFWorkflowActionIdentifier": "is.workflow.actions.downloadurl", "WFWorkflowActionParameters": {
                "UUID": uid, "WFURL": url, "WFHTTPMethod": "POST", "ShowHeaders": True,
                "WFHTTPHeaders": intestazioni, "WFHTTPBodyType": "File",
                "WFRequestVariable": {"Value": {"Type": "ExtensionInput"}, "WFSerializationType": "WFTextTokenAttachment"}}},
            {"WFWorkflowActionIdentifier": "is.workflow.actions.notification", "WFWorkflowActionParameters": {
                "WFNotificationActionTitle": "Riunione inviata",
                "WFNotificationActionBody": risposta,
                "WFNotificationActionSound": True}},
        ]}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--url", required=True)
    ap.add_argument("--segreto", required=True, help="file con il segreto (riunioni.py segreto, sul server)")
    ap.add_argument("--uscita", default=os.path.expanduser("~/Desktop"))
    ap.add_argument("--nome", default="Manda riunione")
    a = ap.parse_args()
    if sys.platform != "darwin" or not shutil.which("shortcuts"):
        sys.exit("scorciatoia: serve un Mac con il comando «shortcuts» (Comandi rapidi)")
    if not a.url.startswith("https://") or not a.url.rstrip("/").endswith("/riunione"):
        sys.exit("scorciatoia: l'indirizzo deve essere https://<nome del server>/riunione")
    seg = open(a.segreto, encoding="utf-8").read().strip()
    if len(seg) < 20:
        sys.exit("scorciatoia: il file del segreto sembra vuoto o troppo corto")
    os.makedirs(a.uscita, exist_ok=True)
    firmato = os.path.join(a.uscita, a.nome + ".shortcut")
    d = tempfile.mkdtemp(prefix="metis-scorciatoia-")
    try:
        grezzo = os.path.join(d, "grezzo.shortcut")
        with open(os.open(grezzo, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), "wb") as f:
            plistlib.dump(flusso(a.url, seg), f, fmt=plistlib.FMT_BINARY)
        r = subprocess.run(["shortcuts", "sign", "--mode", "anyone", "--input", grezzo, "--output", firmato],
                           capture_output=True, text=True, timeout=120)
    finally:
        shutil.rmtree(d, ignore_errors=True)   # la copia non firmata ha il segreto in chiaro
    if r.returncode != 0 or not os.path.exists(firmato):
        sys.exit(f"scorciatoia: firma non riuscita: {(r.stderr or r.stdout).strip()[-300:]}")
    os.chmod(firmato, 0o600)
    print(f"✅ {firmato} — mandalo al cliente (AirDrop o mail a se stesso) e aprilo sull'iPhone: contiene il segreto.")


if __name__ == "__main__":
    main()
