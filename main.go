package main

import (
	"bytes"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"fmt"
	"net/http"
	"net/url"
	"strconv"
	"time"
)

func main() {
	// 1. Details from your connection string
	namespace := "signoz-integration"
	eventHub := "logs"
	sasKeyName := "RootManageSharedAccessKey"
	sasKey := "xxx"

	// 2. Resource URI (must be lowercase)
	resourceURI := fmt.Sprintf("https://%s.servicebus.windows.net/%s", namespace, eventHub)

	// 3. Generate SAS Token
	token := generateSASToken(resourceURI, sasKeyName, sasKey)

	// 4. Send the POST request
	url := fmt.Sprintf("%s/messages", resourceURI)
	body := []byte(`{
    "records": [
        {
            "time": "` + time.Now().Format(time.RFC3339) + `",
            "resourceId": "/SUBSCRIPTIONS/EXTERNAL/LOGS",
            "category": "CustomLog",
            "operationName": "PostLog",
            "properties": {
                "message": "Hello SigNoz via Event Hub!",
                "app_name": "my-go-app"
            }
        }
    ]
}`)

	req, _ := http.NewRequest("POST", url, bytes.NewBuffer(body))
	req.Header.Set("Authorization", token)
	req.Header.Set("Content-Type", "application/atom+xml;type=entry;charset=utf-8")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		fmt.Println("Error:", err)
		return
	}
	defer resp.Body.Close()

	fmt.Println("Response Status:", resp.Status)
}

func generateSASToken(resourceURI, keyName, key string) string {
	// Set expiry for 1 hour from now
	expiry := strconv.FormatInt(time.Now().Unix()+3600, 10)

	encodedURI := url.QueryEscape(resourceURI)
	stringToSign := encodedURI + "\n" + expiry

	mac := hmac.New(sha256.New, []byte(key))
	mac.Write([]byte(stringToSign))
	signature := base64.StdEncoding.EncodeToString(mac.Sum(nil))

	return fmt.Sprintf("SharedAccessSignature sr=%s&sig=%s&se=%s&skn=%s",
		encodedURI, url.QueryEscape(signature), expiry, keyName)
}
