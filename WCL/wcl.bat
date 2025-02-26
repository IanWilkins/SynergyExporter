rem set JAVA_HOME=C:\IBM\jdk-11.0.19+7
set PLAIN_JAVA=C:\RTC703Dev\installs\PlainJavaApi

rem In the -Djava.ext.dirs always keep the Java distribution in the front
"%JAVA_HOME%\bin\java" -Djava.security.policy=rmi_no.policy -cp "%JAVA_HOME%/lib/ext;./lib/*;%PLAIN_JAVA%/*;wcl.jar" com.ibm.js.team.workitem.commandline.WorkitemCommandLine %*