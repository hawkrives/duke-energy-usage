#!/usr/bin/env bash

rye run sqlite-utils create-database usage.sqlite3 --enable-wal

xq <usage.xml . |
	jq -c '
		.["ns3:entry"]["ns3:content"]["espi:IntervalBlock"]["espi:IntervalReading"] 
		| map({
			timestamp: .["espi:timePeriod"]["espi:start"], 
			value: .["espi:value"], 
			type: .["espi:readingQuality"]
		})
		| .[]
	' | rye run sqlite-utils upsert usage.sqlite3 electricity - --nl --pk=timestamp
