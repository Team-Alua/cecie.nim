nc 10.0.0.5 1234 << EOF
{"RequestType": "rtUpdateSave", "sourceFolder": "/data/dump", "targetSaveName": "1"}
EOF
echo ""
#nc 10.0.0.5 1234 << EOF
#{"RequestType": "rtKeySet"}
#EOF
#echo ""
#nc 10.0.0.5 1234 << EOF
#{"RequestType": "rtDumpSave", "sourceSaveName": "data0001", "targetFolder": "/data/dump"}
#EOF
#echo ""
#nc 10.0.0.5 1234 << EOF
#{"RequestType": "rtDumpSav", "sourceSaveName": "data0001", "targetFolder": "/data/dump"}
#EOF
#echo ""
