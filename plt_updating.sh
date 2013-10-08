#! /bin/ash

#####################################################################
# During dynamic updating file system, the power loss event is
# triggered. Check all other static file
# 6-17-2013
#####################################################################

help()
{
cat << HELP
OPTIONS:
	-h	help
	-n	indicate how many times you want this test to go through
HELP
exit 0
}

[ -z "$1" ] && help
[ "$1" = "-h" ] && help

MOUNT_POINT=/mnt/sdcard
MOUNTED=/dev/mmcblk0p1

DYNAMIC_DATA_DIR=/usr
DYNAMIC_DATA=dynamic_data
STATIC_DATA=static
DYNAMIC_DATA_SIZE=`ls -s ${DYNAMIC_DATA_DIR}/${DYNAMIC_DATA} | cut -d " " -f1`
STATIC_FILE_POS=/usr/static

PERCENTAGE_TO_GO=10
BLOCKS_TO_GO=`expr $DYNAMIC_DATA_SIZE / ${PERCENTAGE_TO_GO}`
SLEEP_DURATION=1

THIS_FILE=plt_updating.sh

i=1

remount()
{
	mountpoint -q ${MOUNT_POINT}
	if [ $? -ne 0 ]; then
		echo "Ready to mount."
	else
		echo "${MOUNT_POINT} is already a mountpoint, unmount it firstly."
		umount -f ${MOUNT_POINT}
		echo "Unmount done"
	fi

	mount ${MOUNTED} ${MOUNT_POINT}
	if [ $? -ne 0 ]; then
		echo "ERROR: mount fail!!!"
		exit 1
	fi
	echo "File system mounted successfully!"
}

killThread()
{
	echo `ps | grep $1`
	wpid=`ps | grep "cp /usr/dynamic_data /mnt/" | awk '{print $1}'`
	kill $wpid
	echo "DEAMON thread " $wpid " killed!"
}

dataCheck()
{
	echo "In dataCheck(), remount first"
	remount
	echo "Checking data..."
	for file in `ls $1`
	do
		diff ${DYNAMIC_DATA_DIR}/${STATIC_DATA} $1/$file
		if [ $? -ne 0 ]; then
			echo "Data Check: Corruption Locat in " $file
			diff -uN ${DYNAMIC_DATA_DIR}/${STATIC_DATA} $1/$file > ${DYNAMIC_DATA_DIR}/${file}.patch
			exit 1
		fi
	done
	echo "NO DATA CORRUPTION FOUND!!!!!"
}

mmcWritingPowerLoss()
{
	echo "Dynamic data size in block is" $DYNAMIC_DATA_SIZE
	echo "Power loss will happen at about " ${BLOCKS_TO_GO} " blocks"
	count=`ls -s ${MOUNT_POINT}/${DYNAMIC_DATA}`
	while [ `echo $count | cut -d " " -f1` -le  ${BLOCKS_TO_GO} ]
	do
		sleep ${SLEEP_DURATION}
		count=`ls -s ${MOUNT_POINT}/${DYNAMIC_DATA}`
	done
	power -a 0
	echo "POWER DOWN!!!!"
	#wpid=`ps | grep ${THIS_FILE} | awk '{print $1}' | awk 'NR==2'`	
	#kill $wpid
	wpid=`ps | grep "cp /usr/dynamic_data /mnt/" | awk '{print $1}'`
	kill $wpid
	echo `echo $count | cut -d " " -f1` "blocks dynamic data have been written into eMMC"
	echo "The DEAMON writting threads " $wpid " is killed."
}

mmcSyncingPowerLoss()
{
	echo "Terminate writing process at about " ${BLOCKS_TO_GO} " blocks"
	killThread /usr/dynamic_data
	#wpid=`ps | grep "cp /usr/dynamic_data /mnt/" | awk '{print $1}'`
	echo `echo $count | cut -d " " -f1` "blocks dynamic data have been written into eMMC"
}

writeDynamicData()
{
	echo "Start writing dynamic data to media..."
	cp ${DYNAMIC_DATA_DIR}/${DYNAMIC_DATA} ${MOUNT_POINT}/
#	if [ $? -ne 0 ]; then
#		echo "ERROR: Fail writing dynamic data."
#		exit 1;
#	fi
#	echo "Writing dynamic data complete."
}


while [ $i -le $1 ]
do
#power -a 1 #power on firstly
echo "Sample sequence " $i
ran=`echo $RANDOM`
#echo $ran
echo $RANDOM
a=`echo $ran | cut -b1-2`
#b=`echo $ran | cut -b1`
PERCENTAGE_TO_GO=$a #`expr $a \* 10 + $b`
echo $PERCENTAGE_TO_GO
BLOCKS_TO_GO=`expr $DYNAMIC_DATA_SIZE / ${PERCENTAGE_TO_GO}`

mmcinit -q

remount

if [ ! -f ${DYNAMIC_DATA_DIR}/dynamic_data ]; then
	echo "ERROR: can not find dynamic data!!!"
	exit 1
fi

if [ ! -f ${MOUNT_POINT}/${DYNAMIC_DATA} ]; then
	echo "Dynamic data not found."
else 
	echo "Clear old dynamic data."
	rm -rf ${MOUNT_POINT}/${DYNAMIC_DATA} && sync && sync
fi
touch ${MOUNT_POINT}/${DYNAMIC_DATA}
echo "New empty dynamic data built." 

if [ ! -d ${STATIC_FILE_POS} ]; then
	echo "ERROR: can not find static data!!!"
	exit 1
fi

if [ ! -d ${MOUNT_POINT}/static ]; then
	echo "Target static dir not found."
else
	echo "Target static dir exists, now re-build it."
	rm -rf ${MOUNT_POINT}/static && sync && sync
fi
	
echo "Creating static data..."
cp -aRp ${STATIC_FILE_POS} ${MOUNT_POINT}/
if [ $? -ne 0 ]; then
	echo "ERROR: copy static data aborted!!!"
	exit 1
fi	
sync && sync
if [ $? -ne 0 ]; then
	echo "ERROR: sync problem!!!"
	exit 1
fi 
echo "Sync done"

writeDynamicData&
#sync&  #sync in background
mmcWritingPowerLoss ${MOUNT_POINT}/${DYNAMIC_DATA}
power -a 1 #Power on before data check
mmcinit -q
#mmcSyncingPowerLoss
dataCheck ${MOUNT_POINT}/static
i=`expr $i + 1`
wait
echo "######################################################################################################"
done
