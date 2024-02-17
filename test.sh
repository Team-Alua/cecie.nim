#nc 10.0.0.5 1234 << EOF
#{"RequestType": "rtResignSave", "resign": {"saveName": "data0001", "accountId": 4451199660695826245}}
#EOF
#
#nc 10.0.0.5 1234 << EOF
#{"RequestType": "rtDumpSave", "dump": {"saveName": "data0001", "targetFolder": "/data/dump", "selectOnly": []}}
#EOF
#
#nc 10.0.0.5 1234 << EOF
#{"RequestType": "rtUpdateSave", "update": {"saveName": "data0001", "sourceFolder": "/data/dump", "selectOnly": []}}
#EOF
#
#nc 10.0.0.5 1234 << EOF
#{"RequestType": "rtListSaveFiles", "list": {"saveName": "data0001"}}
#EOF
#
#nc 10.0.0.5 1234 << EOF
#{"RequestType": "rtKeySet"}
#EOF
#
#nc 10.0.0.5 1234 << EOF
#{"RequestType": "rtClean", "clean": {"saveName": "data0001", "folder": "/data/dump"}}
#EOF
#
#nc 10.0.0.5 1234 << EOF
#{"RequestType": "rtUploadFile", "upload": {"target": "/data/dump2/abc.txt", "size": 1}}
#a
#EOF

nc 10.0.0.5 1234 > /dev/null << EOF
{"RequestType": "rtDownloadFile", "download": {"source": "/data/dump2/abc.txt"}}
EOF

