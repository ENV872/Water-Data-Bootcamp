#Read in USGS data - monthly streamflow statistics
install.packages("dataRetrieval", repos=c("http://owi.usgs.gov/R", getOption("repos")))
library(dataRetrieval)
library (ggplot2)
library(EGRET)
library(dplyr); library(magrittr)
library(lubridate)
#Calculate a running seven day average of streamflow
library(TTR)

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

#Use EGRET package
Daily <- readNWISDaily(siteNumber = siteNo, parameterCd = pcode, startDate=start.date, endDate=end.date)
  #notice the Q7 is already calculated for you
  #also notice that Q is now in cms (not cfs)
  #You can start here, but we will start at the beginning and learn how to calculate running averages

#Some things you can do
INFO <- readNWISInfo(siteNo,"",interactive=FALSE)
  eList <- as.egret(INFO, Daily, NA, NA)
  
  #grab all summer months: June-Aug
  eList <- setPA(eList, paStart=6, paLong=3)
  plotFlowSingle(eList, istat=5, qUnit="cfs")
  
  #plot four values
  eList <- as.egret(INFO, Daily, NA, NA)
  plotFour(eList, qUnit=4)
  
  #How has flow changed over time?
  #These statistics are: (1) 1-day minimum, (2) 7-day minimum, (3) 30-day minimum, (4) median, (5) mean, 
  #(6) 30-day maximum, (7) 7-day maximum, and (8) 1-day maximum. 
  #tableFlowChange(eList, istat=2, qUnit=4,yearPoints=c(1930,1984,2017))
######################################################################################################################################
  
  
  

#Load in data
neuse <- readNWISdv(siteNumbers = siteNo, parameterCd = pcode, statCd = scode, startDate=start.date, endDate=end.date)
  summary(neuse); dim(neuse)
#rename columns to something more useful
  neuse <- renameNWISColumns(neuse); colnames(neuse)

#Create cms column to plot cubic meters per second
neuse$Flow_cms <- neuse$Flow*0.028316847
  summary(neuse)
#################################################################################################################################



#################################################################################################################################
##############                                 7Q10                                ############################
neuse$Q7 <- SMA(neuse$Flow_cms,7) #the first 7 observations are not included
  summary(neuse)  
  
#For each year, calculate the minimum Q7
neuse$Year <- year(neuse$Date);  neuse$Month <- month(neuse$Date)
  
#Maximum Annual Flow
low.flow <- neuse %>%
  group_by(Year) %>%
  summarise(MinQ7 = min(Q7, na.rm=T), n=n()) %>%  round(3)

low.flow <- as.data.frame(low.flow);  
#remove rows missing more than 10% of data
low.flow <- subset(low.flow, n>=(365-365*.1))

#rank flows
low.flow <- arrange(low.flow, (MinQ7)); low.flow[1:5,]
low.flow$Rank <- rank(low.flow$MinQ7); low.flow[1:5,]

n.years <- dim(low.flow)[1]; n.years
low.flow$ReturnInterval <- (n.years+1)/low.flow$Rank; low.flow[1:5,]
low.flow$AnnualProb <- round(1/low.flow$ReturnInterval*100,3);  low.flow[1:5,]


#What is the 7Q10?  
#Basic plot
par(mar = c(5,5,3,5)) #set plot margins
plot(low.flow$AnnualProb, low.flow$MinQ7, type='n', yaxt="n", xlim=c(1,100),
     ylab="Min Q7 Streamflow (cms)", xlab = 'Probability of smaller flows')
axis(2, las=2, cex.axis=0.9)
points(low.flow$AnnualProb, low.flow$MinQ7, col=rgb(0,0,0,0.8), cex=0.8, pch=19)  
  abline(v=10, lty=4, col="black")

#linear regression
linear = lm(MinQ7 ~ AnnualProb , data = low.flow);
  summary(linear)
exp.lm = lm(log(MinQ7) ~ (AnnualProb), data=low.flow)
  summary(exp.lm) 

#linear is pretty close
  x.est <- as.data.frame(seq(0,100,10)); colnames(x.est)<-"AnnualProb"
  y.est <- predict(linear,x.est, interval="confidence")
  y.est <- as.data.frame(y.est)
  
  y.est.exp <- as.data.frame(exp(predict(exp.lm,x.est, interval="confidence")))
  
  #Add to plot
  lines(x.est$AnnualProb, y.est$fit, col="red", lty=3, lwd=2);
  lines(x.est$AnnualProb, y.est.exp$fit, col="darkgreen", lty=5, lwd=2)

  
#What is the 7Q10 low flow value?
low.7Q10 <- predict(linear,filter(x.est,AnnualProb==10),interval="confidence"); low.7Q10
abline(h=low.7Q10[1], col="black", lty=2, lwd=2)
  
low.days <- subset(neuse, Flow_cms <= low.7Q10[1]); dim(low.days)
  n.years <- length(unique(low.days$Year))
  print(paste0("Probability of occurrence: ", round(n.years/length(unique(neuse$Year))*100,2)))
  
#plot low flow days
  plot(neuse$Date, neuse$Flow_cms, type='n', yaxt="n", ylim=c(0,200),
       ylab="Streamflow (cms)", xlab = '')
  axis(2, las=2, cex.axis=0.9)
  lines(neuse$Date, neuse$Flow_cms, lwd=1, col=rgb(0,0,1,0.3))
  
  points(low.days$Date, low.days$Flow_cms, col=rgb(1,0,0,0.8), pch=19)  
  abline(v=c(as.Date("1981-01-01"), as.Date("1984-01-01")), lty=2, col="black", lwd=3)
  abline(h=low.7Q10, col="red", lty=4)
    #they all occur before Falls Lake reservoir was established  
  
  
  
##############################################################################################################################################################  
#What does the 7Q10 look like after Falls Lake was established?  
##############################################################################################################################################################
  #change the above to a function and rerun
Fun_7q10 = function(data, ndays){   
data$Q7 <- SMA(data$Flow_cms, ndays) #the first 7 observations are not included
  
  #For each year, calculate the minimum Q7
  data$Year <- year(data$Date);  data$Month <- month(data$Date)
  
  #Maximum Annual Flow
  low.flow <- data %>%
    group_by(Year) %>%
    summarise(MinQ7 = min(Q7, na.rm=T), n=n()) %>%  round(3)
  
  low.flow <- as.data.frame(low.flow);  
  #remove rows missing more than 10% of data
  low.flow <- subset(low.flow, n>=(365-365*.1))
  
  #rank flows
  low.flow <- arrange(low.flow, (MinQ7)); low.flow[1:5,]
  low.flow$Rank <- rank(low.flow$MinQ7); low.flow[1:5,]
  
  n.years <- dim(low.flow)[1]; n.years
  low.flow$ReturnInterval <- (n.years+1)/low.flow$Rank; low.flow[1:5,]
  low.flow$AnnualProb <- round(1/low.flow$ReturnInterval*100,3);  low.flow[1:5,]
  
  return (low.flow)
} #end function
  
post.falls <- subset(neuse, Date>="1984-01-01")
#call function
low.flow.post <- Fun_7q10(post.falls, 7)


#Basic plot
par(mar = c(5,5,3,5)) #set plot margins
  plot(low.flow.post$AnnualProb, low.flow.post$MinQ7, type='n', yaxt="n", xlim=c(1,100), ylim=c(0,12),
       ylab="Min Q7 Streamflow (cms)", xlab = 'Annual Probability of Exceedance')
  axis(2, las=2, cex.axis=0.9)
  points(low.flow.post$AnnualProb, low.flow.post$MinQ7, col=rgb(0.7,0.5,0,0.8), cex=1, pch=19)  
  abline(v=10, lty=4, col="black")
  
  #linear regression
  linear.post = lm(MinQ7 ~ AnnualProb , data = low.flow.post);
    summary(linear)
  exp.lm.post = lm(log(MinQ7) ~ (AnnualProb), data=low.flow.post)
    summary(exp.lm) 
  
  #linear is pretty close
  y.est.post <- predict(linear.post,x.est, interval="confidence")
  y.est.post <- as.data.frame(y.est.post)
  y.est.exp.post <- as.data.frame(exp(predict(exp.lm.post,x.est, interval="confidence")))
  
  #Add to plot
  #lines(x.est$AnnualProb, y.est.post$fit, col="red", lty=3,lwd=2);
  #lines(x.est$AnnualProb, y.est.exp.post$fit, col="darkgreen", pch=4)
  
#What is the 7Q10 low flow value?
  low.7Q10.post <- predict(linear.post,filter(x.est,AnnualProb==10),interval="confidence"); low.7Q10.post
  abline(h=low.7Q10.post[1], col=rgb(0.7,0.5,0), lty=2, lwd=2)
    #abline(h=low.7Q10.post, col="black", lty=4)
  
#add original low flow value
  abline(h=low.7Q10[1], col="red", lty=4)
  points(low.flow$AnnualProb, low.flow$MinQ7, col=rgb(1,0,0,0.8), cex=0.6, pch=19)  

legend("top", c("Post Falls Lake Annual Low Flow", "Post Falls Lake 7Q10", "POR Annual Low Flow", "POR 7Q10"), col=c("goldenrod3","goldenrod3","red","red"),
       pch=c(19,NA,19,NA), lty=c(0,2,0,4))

print(paste0("Min Flow increased by ", round((low.7Q10.post[1]-low.7Q10[1])/low.7Q10[1]*100,2), "%"))


#plot low flow days
plot(neuse$Date, neuse$Flow_cms, type='n', yaxt="n", ylim=c(0,20),
     ylab="Streamflow (cms)", xlab = '')
axis(2, las=2, cex.axis=0.9)
lines(neuse$Date, neuse$Flow_cms, lwd=1, col=rgb(0,0,1,0.3))

low.days.post <- subset(neuse, Flow_cms <= low.7Q10.post[1]); dim(low.days.post)
points(low.days.post$Date, low.days.post$Flow_cms, col=rgb(1,0,0,0.6), pch=19, cex=0.8)  
abline(v=c(as.Date("1981-01-01"), as.Date("1984-01-01")), lty=2, col="black", lwd=3)
abline(h=low.7Q10.post[1], col="red", lty=4)
points(low.days$Date, low.days$Flow_cms, col=rgb(0.7,0,0,0.6), pch=19)  
abline(h=low.7Q10[1], col="darkred", lty=4)

n.years.post <- length(unique(low.days.post$Year))


##############################################################################################################################################################  
#                  Create a dataframe summarizing results
##############################################################################################################################################################
RI.table <- as.data.frame(matrix(nrow=2, ncol=5));    colnames(RI.table) <- c("Date.Range", "7Q10_cms","No_Days","Annual_Prob","AdjustedR2")
  RI.table$Date.Range <- c("1930-2017","1984-2017")
  RI.table$`7Q10_cms` <- c(round(low.7Q10[1],3), round(low.7Q10.post[1],3))
  RI.table$No_Days <- c(n.years, n.years.post)
  RI.table$Annual_Prob <- c(round(n.years/length(unique(neuse$Year))*100,2), round(n.years.post/length(unique(neuse$Year))*100,2))
  RI.table$AdjustedR2 <- c(summary(exp.lm)$adj.r.squared, summary(exp.lm.post)$adj.r.squared)

RI.table







