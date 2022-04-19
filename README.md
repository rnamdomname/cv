Это пример для резюме

This example for CV

Trying to follow "Immutable Infrastucture" pattern...

Needs at least ``` 7600.16385.090713-1255_x86fre_enterprise_en-us_EVAL_Eval_Enterprise-GRMCENEVAL_EN_DVD.iso```

Build steps

```
cd w7x64
bash build_container.sh
```

Run the image
```
docker run  --rm -d -p 4442-4444:4442-4444 --net grid --name selenium-hub selenium/hub:4.1.2
docker run --net grid --rm -it -e "VMMEM=2048"   --device=/dev/kvm   modernie:w7x64
```


![selenium hub](https://raw.githubusercontent.com/antnn/selenium-static/main/Screenshot%202022-04-05%20at%2023-11-28%20Selenium%20Grid.png "selenium hub")
![win7](https://raw.githubusercontent.com/antnn/selenium-static/main/Screenshot%20from%202022-04-05%2023-12-01.png "win7")
