#Read in USGS data - monthly streamflow statistics
install.packages("dataRetrieval", repos=c("http://owi.usgs.gov/R", getOption("repos")))
library(dataRetrieval); library(EGRET);
library (ggplot2)
library(dplyr); library(magrittr)
library(lubridate)


rm(list=ls()) #removes anything stored in memory
#################################################################################################################################
##############                                  DOWNLOAD DATA                                        ############################
#################################################################################################################################
#Identify gauge to download
siteNo <- '02087500' #don't forget to add the zero if it is missing

#Identify parameter of interest: https://help.waterdata.usgs.gov/code/parameter_cd_query?fmt=rdb&inline=true&group_cd=%
pcode = '00060' #discharge (cfs)

#Identify statistic code for daily values: https://help.waterdata.usgs.gov/code/stat_cd_nm_query?stat_nm_cd=%25&fmt=html
scode = "00003"  #mean

#Identify start and end dates
start.date = "1930-10-01"
end.date = "2017-09-30"

#pick service
serv <- "dv"


#Load in Ndata using the site ID
neuse <- readNWISdv(siteNumbers = siteNo, parameterCd = pcode, statCd = scode, startDate=start.date, endDate=end.date)
  summary(neuse); dim(neuse)
#rename columns to something more useful
  neuse <- renameNWISColumns(neuse); colnames(neuse)

#Create cms column to plot cubic meters per second
neuse$Flow_cms <- neuse$Flow*0.028316847
  summary(neuse)
#################################################################################################################################



#################################################################################################################################
##############                                  Flood Return Interval                                 ############################
#################################################################################################################################
neuse$Year <- year(neuse$Date);  neuse$Month <- month(neuse$Date)
  summary(neuse)  

#calculate the Water Year
neuse$WaterYear <- ifelse(neuse$Month>=10, neuse$Year+1, neuse$Year)

#Maximum Annual Flow
peak.flow <- neuse %>%
  group_by(WaterYear) %>%
  summarise(Peak_cms = max(Flow_cms, na.rm=T), n=n()) %>%  round(3)
  
peak.flow <- as.data.frame(peak.flow); peak.flow  
#remove rows missing more than 10% of data
peak.flow <- subset(peak.flow, n>=(365-365*.1))

#rank flows
peak.flow <- arrange(peak.flow, desc(Peak_cms)); peak.flow[1:5,]   #arranges data in descending order based on the Peak_cms column
peak.flow$Rank <- rank(-peak.flow$Peak_cms); peak.flow[1:5,]       #adds a column with rank from 1 to n

n.years <- dim(peak.flow)[1]; n.years
peak.flow$ReturnInterval <- (n.years+1)/peak.flow$Rank; peak.flow[1:5,]
peak.flow$AnnualProb <- round(1/peak.flow$ReturnInterval*100,3);  peak.flow[1:5,]


#Basic plot
par(mfrow=c(1,1))
par(mar = c(5,5,3,5)) #set plot margins
plot(peak.flow$ReturnInterval, peak.flow$Peak_cms, log="x", type='n', yaxt="n", xlim=c(1,1000), ylim=c(0,1000),
     ylab="Peak Streamflow (cms)", xlab = 'Return Interval (Years)')
  axis(2, las=2, cex.axis=0.9)
  minor.ticks <- c(2,3,4,6,7,8,9,20,30,40,60,70,80,90,200,300,400,600,700,800,900)     #trick to add tick marks to log axis
  axis(1,at=minor.ticks,labels=FALSE, col="darkgray")                                 
box()
  points(peak.flow$ReturnInterval, peak.flow$Peak_cms, col=rgb(0,0,0,0.6), cex=1.2, pch=19)  

#linear regression
RI.linear = lm(Peak_cms ~ ReturnInterval , data = peak.flow); RI.linear
  summary(RI.linear)
RI.log = lm(Peak_cms ~ log(ReturnInterval), data=peak.flow)
  summary(RI.log)
  
#Estimate the streamflow at the following return intervals using the log regression
x.est <- as.data.frame(c(100,200,500,1000)); colnames(x.est)<-"ReturnInterval"
y.est <- predict(RI.log,x.est, interval="confidence")
  y.est <- as.data.frame(y.est)
  y100 = cbind(x.est, y.est);  y100 <- subset(y100, x.est==100)$fit
  y100
  
#Add to plot
points(x.est$ReturnInterval, y.est$fit, col="red", pch=2, lwd=2);
#  polygon(c(x.est$ReturnInterval, rev(x.est$ReturnInterval)), c(y.est$lwr, rev(y.est$upr)), col=rgb(1,0,0,0.2), border="NA");
#################################################################################################################################



#################################################################################################################################
##############                                  Turn Into a Function and Recalculate                                 ############################
################################################################################################################################# 
flood_int = function(data){ 
  #Maximum Annual Flow
  peak.flow <- data %>%
    group_by(WaterYear) %>%
    summarise(Peak_cms = max(Flow_cms, na.rm=T), n=n()) %>%  round(3)
  
  peak.flow <- as.data.frame(peak.flow); 
  #remove rows missing more than 10% of data
  peak.flow <- subset(peak.flow, n>=(365-365*.1))
  
  #rank flows
  peak.flow <- arrange(peak.flow, desc(Peak_cms)); peak.flow[1:5,]
  peak.flow$Rank <- rank(-peak.flow$Peak_cms); peak.flow[1:5,]
  
  n.years <- dim(peak.flow)[1]; n.years
  peak.flow$ReturnInterval <- (n.years+1)/peak.flow$Rank; peak.flow[1:5,]
  peak.flow$AnnualProb <- round(1/peak.flow$ReturnInterval*100,3);  peak.flow[1:5,]
  
  return (peak.flow)
}

#########################################################################################################################
#call function for early time period
#########################################################################################################################
neuse.early <- subset(neuse, Date>="1930-01-01" & Date<="1979-12-31");          summary(neuse.early)
peak.flow.early <- flood_int(neuse.early)   ;
summary(peak.flow.early)  
  
#Basic plot
par(mar = c(5,5,3,5)) #set plot margins
plot(peak.flow.early$ReturnInterval, peak.flow.early$Peak_cms, log="x", type='n', yaxt="n", xlim=c(1,1000), ylim=c(0,1000),
     ylab="Peak Streamflow (cms)", xlab = 'Return Interval (Years)')
axis(2, las=2, cex.axis=0.9)
axis(1,at=minor.ticks,labels=FALSE, col="darkgray")                                 
  box()
points(peak.flow.early$ReturnInterval, peak.flow.early$Peak_cms, col=rgb(0,0,0,0.6), cex=1.2, pch=19)  
 
#linear regression
RI.linear.early = lm(Peak_cms ~ ReturnInterval , data = peak.flow.early);
  summary(RI.linear.early)
RI.log.early = lm(Peak_cms ~ log(ReturnInterval), data=peak.flow.early)
  summary(RI.log.early) 
  
#plot log line
  x.est <- as.data.frame(c(100,200,500,1000)); colnames(x.est)<-"ReturnInterval"
  y.est.pre <- predict(RI.log.early,x.est, interval="confidence")
  y.est.pre <- as.data.frame(y.est.pre)
  points(x.est$ReturnInterval, y.est.pre$fit, col="black", pch=5, lwd=2);

#plot original return intervals  
points(peak.flow$ReturnInterval, peak.flow$Peak_cms, col=rgb(0,0,1,0.5), cex=0.8, pch=19)  
  points(x.est$ReturnInterval, y.est.pre$fit, col="blue", pch=2, lwd=2);
    abline(h=y.est.pre$fit[1], col="black", lty=3); abline(v=100, col="red", lty=3)
    abline(h=y100, col="blue", lty=3)
legend("bottomright", c("Period of Record","1930-1979 data", "Est. Flow POR", "Est.Flow 1930-1979"), col=c("blue","black","blue","black"), pch=c(19,19,2,5))



#########################################################################################################################
#call function for later time period
#########################################################################################################################
neuse.late <- subset(neuse, Date>="1984-01-01");          summary(neuse.late)
peak.flow.late <- flood_int(neuse.late)   ;
summary(peak.flow.late)  

#Basic plot
par(mar = c(5,5,3,5)) #set plot margins
plot(peak.flow.late$ReturnInterval, peak.flow.late$Peak_cms, log="x", type='n', yaxt="n", xlim=c(1,1000), ylim=c(0,1000),
     ylab="Peak Streamflow (cms)", xlab = 'Return Interval (Years)')
axis(2, las=2, cex.axis=0.9)
axis(1,at=minor.ticks,labels=FALSE, col="darkgray")                                 
box()
points(peak.flow.late$ReturnInterval, peak.flow.late$Peak_cms, col=rgb(0.7,0.4,0,0.6), cex=1.2, pch=19)  

#linear regression
RI.linear.late = lm(Peak_cms ~ ReturnInterval , data = peak.flow.late);
  summary(RI.linear.late)
RI.log.late = lm(Peak_cms ~ log(ReturnInterval), data=peak.flow.late)
  summary(RI.log.late) 

#plot log line
y.est.post <- predict(RI.log.late,x.est, interval="confidence")
  y.est.post <- as.data.frame(y.est.post)
points(x.est$ReturnInterval, y.est.post$fit, col="goldenrod3", pch=12, lwd=2);

#plot original return intervals  
points(peak.flow$ReturnInterval, peak.flow$Peak_cms, col=rgb(0,0,1,0.5), cex=0.8, pch=19)  
points(x.est$ReturnInterval, y.est.pre$fit, col="blue", pch=2, lwd=2);

#plot early return interval
points(x.est$ReturnInterval, y.est.pre$fit, col="black", pch=5, lwd=2);

#draw ablines
abline(h=c(y100,y.est.pre$fit[1],y.est.post$fit[1]), col=c("blue","black","goldenrod3"), lty=3);
abline(v=100, col="black", lty=3)

legend("bottomright", c("Period of Record","1984-2017 data", "Est. Flow POR", "Est.Flow 1930-1979", "Est.Flow 1984-2017"), 
       col=c("blue","goldenrod3","blue","black","goldenrod3"), pch=c(19,19,2,5,12))
###################################################################################################################

#Less 3 hurricanes
RI.log.hur <- lm(Peak_cms ~log(ReturnInterval), data=peak.flow.late[c(4:dim(peak.flow.late)[1]),])
  y.est.hur <- as.data.frame(predict(RI.log.hur,x.est, interval="confidence")); y.est.hur
#plot hurricane
  points(x.est$ReturnInterval, y.est.hur$fit, col="red", pch=16, lwd=2);
  abline(h=y.est.hur$fit[1], col="red", lty=3)
  
  
############## Create Return Interval Table
RI.table <- as.data.frame(matrix(nrow=4, ncol=6));    colnames(RI.table) <- c("Date.Range", "RI_100yr","RI_500yr","RI_1000yr","Nyears","AdjustedR2")
  RI.table$Date.Range <- c("1930-2017","1930-1979","1984-2017","Less 3 Hurricanes")
  RI.table$RI_100yr <- c(y.est$fit[1],y.est.pre$fit[1],y.est.post$fit[1], y.est.hur$fit[1])
  RI.table$RI_500yr <- c(y.est$fit[3],y.est.pre$fit[3],y.est.post$fit[3], y.est.hur$fit[3])
  RI.table$RI_1000yr <- c(y.est$fit[4],y.est.pre$fit[4],y.est.post$fit[4], y.est.hur$fit[4])
  RI.table$Nyears <- c(dim(peak.flow)[1], dim(peak.flow.early)[1], dim(peak.flow.late)[1], dim(peak.flow.late)[1]-3)
  RI.table$AdjustedR2 <- c(summary(RI.log)$adj.r.squared, summary(RI.log.early)$adj.r.squared, 
                          summary(RI.log.late)$adj.r.squared, summary(RI.log.hur)$adj.r.squared)

RI.table

#What's the probability of these events occurring in a 30 year mortgage??
Rperiod = c(100,500,1000)
n.years = 30
for (i in 1:3){
  print(paste0("Percent likelihood over ", n.years, " years for a ", Rperiod[i]," year flood: ", round((1-(1-(1/Rperiod[i]))^n.years)*100,2), "%"))
}
