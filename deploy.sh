ts=`date`
git pull
hugo -t nofancy
cp -r public/* ../blog-rendered
cd ../blog-rendered && git add . && git commit -S -m"Blog update $ts" && git push

