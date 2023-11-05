nc 10.0.0.5 1234 << EOF
{"RequestType": "rtResignSave", "resign": {"saveName": "data0001", "accountId": 4451199660695826245}}
EOF

nc 10.0.0.5 1234 << EOF
{"RequestType": "rtDumpSave", "dump": {"saveName": "data0001", "targetFolder": "/data/dump", "selectOnly": []}}
EOF

nc 10.0.0.5 1234 << EOF
{"RequestType": "rtUpdateSave", "update": {"saveName": "data0001", "sourceFolder": "/data/dump", "selectOnly": []}}
EOF

nc 10.0.0.5 1234 << EOF
{"RequestType": "rtListSaveFiles", "list": {"saveName": "data0001"}}
EOF

nc 10.0.0.5 1234 << EOF
{"RequestType": "rtKeySet"}
EOF

