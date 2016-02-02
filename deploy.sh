ts=`date`
git pull
hugo -t nofancy -D
cp -r public/* ../blog-rendered
cd ../blog-rendered && git add . && git commit -m"Blog update $ts" && git push

