#!/bin/sh
# cleanup old NVD data
rm -f src/main/resources/nvdcve-2.0-*.json
rm -f src/main/resources/official-cpe-dictionary_v2.3.xml
# Reset CVEService.java years placeholder
CVESERVICE_FILE="src/main/java/com/tam/services/meta/CVEService.java"
sed -i "s/Collections.addAll(fileSpecifications,.*/ Collections.addAll(fileSpecifications, \"##YEARS##\");/" "$CVESERVICE_FILE"

# --- Configuration ---
NVD_DIR="src/main/resources"
# Base URL for the NVD file feeds
NVD_BASE_URL="https://nvd.nist.gov"
mkdir -p "$NVD_DIR"

# --- 1. Define CVE Files to Download ---
echo "--- Defining CVE Feeds ---"

# Special feeds (modified and recent) MUST be added manually as they are not years
CVE_FEEDS="modified recent"

# Yearly feeds: Go from 1999 (when NVD started) up to the current year
CURRENT_YEAR=$(date +"%Y")
START_YEAR=2002
for YEAR in $(seq $START_YEAR $CURRENT_YEAR); do
    CVE_FEEDS="$CVE_FEEDS $YEAR"
done

# Replace placeholder "##YEARS##" with actual years in CVEService.java
YEAR_LIST=$(echo "$CVE_FEEDS" | sed 's/ /", "/g')
sed -i "s/##YEARS##/$YEAR_LIST/" "$CVESERVICE_FILE"

# --- 2. Fetch, Verify, and Unpack CVE Data (JSON 2.0 Feeds) ---
echo "--- Starting NVD CVE 2.0 File Feed Download and Unpack ---"

for FEED in $CVE_FEEDS; do
    
    FILE_BASE="nvdcve-2.0-$FEED"
    JSON_FILE="$FILE_BASE.json"
    ZIP_FILE="$JSON_FILE.zip"
    META_FILE="$FILE_BASE.meta"
    
    ZIP_URL="$NVD_BASE_URL/feeds/json/cve/2.0/$ZIP_FILE"
    META_URL="$NVD_BASE_URL/feeds/json/cve/2.0/$META_FILE"
    
    # 2a. Download META file for checksum
    # curl -sSL is silent, show errors, and follow redirects
    curl -sSL "$META_URL" -o "$NVD_DIR/$META_FILE"
    # Check if the META file is missing or invalid
    if ! grep -q "sha256" "$NVD_DIR/$META_FILE"; then
        echo "  META file suggests no data for $FEED. Skipping."
        rm -f "$NVD_DIR/$META_FILE" 2>/dev/null
        continue
    fi

    # Extract expected SHA256 sum from the META file
    EXPECTED_SHA256=$(grep "sha256" "$NVD_DIR/$META_FILE" | cut -d: -f2 | tr -d ' \t\n\r')
    
    # 2b. Download the ZIP file
    echo "  Downloading ZIP for $FEED..."
    curl -sSL "$ZIP_URL" -o "$NVD_DIR/$ZIP_FILE"
    
    # 2c. Verify Integrity (using sha256sum)
    if command -v sha256sum >/dev/null 2>&1; then
        # 2d. Unpack the JSON file (which is nvdcve-2.0-FEED.json)
        echo "  Unpacking $ZIP_FILE..."
        unzip -o "$NVD_DIR/$ZIP_FILE" -d "$NVD_DIR"
        ACTUAL_SHA256=$(sha256sum "$NVD_DIR/$JSON_FILE" | awk '{print $1}' | tr '[:lower:]' '[:upper:]')
        if [ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]; then
            echo "  ERROR: SHA256 mismatch for $JSON_FILE."
            echo "  Expected: $EXPECTED_SHA256"
            echo "  Actual: $ACTUAL_SHA256"
            exit 1
        else
            echo "  SHA256 verified successfully."
        fi
    else
        echo "  Warning: sha256sum command not found. Skipping integrity check."
    fi
    
    # 2e. Clean up
    rm "$NVD_DIR/$ZIP_FILE"
    rm "$NVD_DIR/$META_FILE"

    echo "Finished processing $FILE_BASE"
done

echo "NVD CVE data fetching complete."
echo "--------------------------------------------------------"

# --- 3. Fetching CPE Data (CPE Dictionary 2.3 XML) ---
echo "--- Starting NVD CPE Dictionary 2.3 XML Download ---"

NVD_BASE_URL="https://web.archive.org/web/20250425180242/$NVD_BASE_URL"
CPE_BASE="official-cpe-dictionary_v2.3"
XML_FILE="$CPE_BASE.xml"
ZIP_FILE="$XML_FILE.zip"
ZIP_URL="$NVD_BASE_URL/feeds/xml/cpe/dictionary/$ZIP_FILE"


# Download the ZIP file
echo "Downloading CPE ZIP file..."
curl -sSL "$ZIP_URL" -o "$NVD_DIR/$ZIP_FILE"

# Unpack the JSON file
echo "Unpacking $ZIP_FILE..."
unzip -o "$NVD_DIR/$ZIP_FILE" -d "$NVD_DIR"

# Clean up
rm "$NVD_DIR/$ZIP_FILE"

echo "NVD CPE data fetching complete."