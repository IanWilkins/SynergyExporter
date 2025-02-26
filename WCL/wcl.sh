#!/bin/sh
JAVA_HOME=/Library/Java/JavaVirtualMachines/ibm-semeru-open-8.jdk/Contents/Home
export JAVA_HOME
PLAIN_JAVA=/Users/ian/Libraries/IBM/EWM-Client-plainJavaLib
export PLAIN_JAVA

# In the -Djava.ext.dirs always keep the Java distribution in the front
#$JAVA_HOME/bin/java -Djava.security.policy=rmi_no.policy -cp "$JAVA_HOME/lib/ext:$JAVA_HOME/jre/lib/ext:./lib:$PLAIN_JAVA:wcl.jar" com.ibm.js.team.workitem.commandline.WorkitemCommandLine "$@"

$JAVA_HOME/bin/java -Djava.security.policy=rmi_no.policy -Djava.ext.dirs="$JAVA_HOME/lib/ext:$JAVA_HOME/jre/lib/ext:./lib:$PLAIN_JAVA" -cp wcl.jar com.ibm.js.team.workitem.commandline.WorkitemCommandLine "$@"


