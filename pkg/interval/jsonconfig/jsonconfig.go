package jsonconfig

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"os"
)

func Load(filename string, ptr interface{}) error {
	cfile, err := os.Open(filename)
	if err != nil {
		return fmt.Errorf("load file %s failed, %w", filename, err)
	}
	fbyte, _ := ioutil.ReadAll(cfile)
	err = json.Unmarshal(fbyte, ptr)
	if err != nil {
		return fmt.Errorf("read all file %s failed, %w", filename, err)
	}
	return nil
}
