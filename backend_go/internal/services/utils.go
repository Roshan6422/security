package services

import (
	"crypto/rand"
	"math/big"
)

// GenerateRandomString creates a secure random string of a given length.
func GenerateRandomString(n int) string {
	const letters = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
	ret := make([]byte, n)
	for i := 0; i < n; i++ {
		num, _ := rand.Int(rand.Reader, big.NewInt(int64(len(letters))))
		ret[i] = letters[num.Int64()]
	}
	return string(ret)
}

func GenerateRandomDigits(n int) string {
	const digits = "0123456789"
	ret := make([]byte, n)
	for i := 0; i < n; i++ {
		num, _ := rand.Int(rand.Reader, big.NewInt(int64(len(digits))))
		ret[i] = digits[num.Int64()]
	}
	return string(ret)
}
