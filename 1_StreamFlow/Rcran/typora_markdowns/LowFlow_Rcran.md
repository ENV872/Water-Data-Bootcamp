---
Title: Analysis of Low Flows Using Rcran
Author: Lauren Patterson and John Fay
Date: Spring 2018
---

# Unit 1: Analysis of Low Flows using Rcran

[TOC]

## Q2: Evaluating impact on minimum flows

#### Background & Framing the Analysis: 7Q10

The passing of the Clean Water Act in 1972 and the Endangered Species Act in 1973 has resulted in many reservoirs having to meet downstream flow requirements for either water quality purposes or species protection. For example, at the Clayton gauge, minimum flow requirements have ranged from 184 to 404 cfs since 1983. *Here we want to see if Falls Lake has raised minimum flows.*

There are many ways to approach low flow to understand how minimum streamflow has changed since Falls Lake was constructed. We will look at a common metric known as 7Q10. <u>**7Q10** is the lowest average discharge over a one [week/month/year] period with a recurrence interval of 10 years.</u> This means there is only a 10% probability that there will be lower flows than the 7Q10 threshold in any given year. 

To get more practice with pivot tables and if statements, we will calculate this metric using the 7 month period. To do this we need to construct a rolling average of monthly discharges spanning 7 month, which we can do using a series of pivot tables. 

The first pivot table aggregates our daily discharge data into total monthly discharge values for each year. From this we table, we can compute a *7-month rolling average of minimum-flows* from the given month's total discharge and those from 6 months preceding it. 

Next, we construct a second Pivot Table from the above data. This one aggregates the monthly data by year, extracting the minimum of the 7-month average for each year. This will enable us to compute a regression similar the one we constructed for the flood return interval, but this regression is to reveal the recurrence interval of low flows so that we can determine the streamflow of a 10% low flow event. 

We then sort and rank these annual monthly-minimum values, similar to how we computed flood return intervals to compute *7 month minimum-flow (7Q) return interval* and then the *low flow probability of recurrence (POR)* of these flows, again using the same methods used for calculating flood return intervals and probabilities of recurrence. From this we can compute a regression between our yearly 7Q flows and POR, and use that regression equation to determine 7Q10, or the expected minimum flow across a span of 10 years. 



#### Obtaining Data

The method for installing and loading libraries, as well as downloading data from the USGS, are explained in the `Streamflow_Rcran.md` file. 

```R
#Load Libraries
library(dataRetrieval); library (ggplot2); library(EGRET); library(dplyr); library(magrittr)
library(lubridate); library(TTR);   #calculates running averages
```

```R
#Download data
#Identify gauge to download
siteNo <- '02087500' #don't forget to add the zero if it is missing

#Identify parameter of interest
pcode = '00060' #discharge (cfs)

#Identify statistic code for daily values: 
scode = "00003"  #mean

#Identify start and end dates
start.date = "1930-10-01"
end.date = "2017-09-30"

#Load in data
neuse <- readNWISdv(siteNumbers = siteNo, parameterCd = pcode, statCd = scode, startDate=start.date, endDate=end.date)
  summary(neuse); dim(neuse)
#rename columns to something more useful
  neuse <- renameNWISColumns(neuse); colnames(neuse)
#Create cms column to plot cubic meters per second
neuse$Flow_cms <- neuse$Flow*0.028316847
```



#### Calculate Low Flow Return Interval

The first step to estimating 7Q10 is to calculate the 7 day average. The `SMA(data, number to average)` function in the `TTR` library is used to calculate rolling averages. In this case we want to average 7 days. This averages from the previous 6 rows and includes the current row (7th) in the average. This means the first 6 observations in your data will not have a value.

```R
neuse$Q7 <- SMA(neuse$Flow_cms,7) #the first 6 observations are not included
	summary(neuse)
```

Next we will use pipes and dplyr to estimate the minimum 7 day average in each year. For more information on pipes and the `rank` and `arrange` functions, see `Streamflow_Rcran.md`. For more information on the formula for calculating a return interval, see `Flood_RI_Rcran.md`.

```R
#Calculate a year and month variable
neuse$Year <- year(neuse$Date);  neuse$Month <- month(neuse$Date)
  
#Calculate the minimum 7 day average flow in each year
low.flow <- neuse %>%
  group_by(Year) %>%
  summarise(MinQ7 = min(Q7, na.rm=T), n=n()) %>% 
  round(3)
low.flow <- as.data.frame(low.flow);  
#remove rows missing more than 10% of data
low.flow <- subset(low.flow, n>=(365-365*.1))

#rank flows - notice the rank is now in ascending order.
low.flow <- arrange(low.flow, (MinQ7)); low.flow[1:5,];
low.flow$Rank <- rank(low.flow$MinQ7); low.flow[1:5,];

#calculate the return interval
n.years <- dim(low.flow)[1]; n.years
low.flow$ReturnInterval <- (n.years+1)/low.flow$Rank; 
low.flow$AnnualProb <- round(1/low.flow$ReturnInterval*100,3);  

#Always check your work to make sure it looks correct
low.flow[1:5,]
```



#### Plot Low Flow Return Interval and Regressions

It always helps to visualize the data. In the case of 7Q10, the data are often plotted against the annual probability of an event occurring (rather than the Return Interval). Similar to the Flood Return Interval exercise, we will fit regressions to the plot. In this instance we will fit linear and exponential curves. Notices the exponential regression is similar to the log regression from before, except it's `log(y-axis)` instead of `log(x-axis)`.

```R
#Plot the data
par(mar = c(5,5,3,5)) #set plot margins
plot(low.flow$AnnualProb, low.flow$MinQ7, type='n', yaxt="n", xlim=c(1,100),
     ylab="Min Q7 Streamflow (cms)", xlab = 'Probability of smaller flows')
axis(2, las=2, cex.axis=0.9)
points(low.flow$AnnualProb, low.flow$MinQ7, col=rgb(0,0,0,0.8), cex=0.8, pch=19)  
  abline(v=10, lty=4, col="black")

#linear regression
linear = lm(MinQ7 ~ AnnualProb , data = low.flow);
  summary(linear)
#exponential regression
exp.lm = lm(log(MinQ7) ~ (AnnualProb), data=low.flow)
  summary(exp.lm) 

#linear is pretty close
  x.est <- as.data.frame(seq(0,100,10)); colnames(x.est)<-"AnnualProb"
  y.est <- predict(linear,x.est, interval="confidence")
  y.est.exp <- as.data.frame(exp(predict(exp.lm,x.est, interval="confidence")))
  
  #Add to plot
  lines(x.est$AnnualProb, y.est$fit, col="red", lty=3, lwd=2);     #linear line
  lines(x.est$AnnualProb, y.est.exp$fit, col="darkgreen", lty=5, lwd=2)  #exponential line
  
#What is the 7Q10 low flow value?
low.7Q10 <- predict(linear,filter(x.est,AnnualProb==10),interval="confidence"); low.7Q10
abline(h=low.7Q10[1], col="black", lty=2, lwd=2)
```



##### Plot when low-flow events occurred

Let's look at when in the time series low flow events took place to see if we notice a difference before and after Falls Lake was constructed. First, we will subset the data to include only those below the 7Q10 value. 

```R
low.days <- subset(neuse, Flow_cms <= low.7Q10[1]); dim(low.days)

#plot low flow days
  plot(neuse$Date, neuse$Flow_cms, type='n', yaxt="n", ylim=c(0,200),
       ylab="Streamflow (cms)", xlab = '')
  axis(2, las=2, cex.axis=0.9)
  lines(neuse$Date, neuse$Flow_cms, lwd=1, col=rgb(0,0,1,0.3))
  
  points(low.days$Date, low.days$Flow_cms, col=rgb(1,0,0,0.8), pch=19)  
  abline(v=c(as.Date("1980-01-01"), as.Date("1984-01-01")), lty=2, col="black", lwd=3)
  abline(h=low.7Q10, col="red", lty=4)
```



#### Use functions to calculate the return interval after Falls Lake

For more information on how functions work in R, see `Streamflow_Rcran.md`.  Essentially we take all of the commands from above and stick them inside a function we name `Fun_7q10` with parameters of `data` and the `number of days in our rolling average`. The function will then return a data frame called `low.flow` with the return interval and annual probabilities included.

```R
Fun_7q10 = function(data, ndays){   
data$Q7 <- SMA(data$Flow_cms, ndays) #the first 7 observations are not included
 
  #For each year, calculate the minimum Q7
  data$Year <- year(data$Date);  data$Month <- month(data$Date)
  
  #Maximum Annual Flow
  low.flow <- data %>%
    group_by(Year) %>%
    summarise(MinQ7 = min(Q7, na.rm=T), n=n()) %>% 
    round(3)
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
```



Next, we call the function, plot the results, and run the regressions.

```R
post.falls <- subset(neuse, Date>="1984-01-01")
#call function
low.flow.post <- Fun_7q10(post.falls, 7)

#Plot the data
par(mar = c(5,5,3,5)) #set plot margins
  plot(low.flow.post$AnnualProb, low.flow.post$MinQ7, type='n', yaxt="n", xlim=c(1,100), ylim=c(0,12),
       ylab="Min Q7 Streamflow (cms)", xlab = 'Annual Probability of Exceedance')
  axis(2, las=2, cex.axis=0.9)
  points(low.flow.post$AnnualProb, low.flow.post$MinQ7, col=rgb(0.7,0.5,0,0.8), cex=1, pch=19)  
  abline(v=10, lty=4, col="black")
  
  #linear regression
  linear.post = lm(MinQ7 ~ AnnualProb , data = low.flow.post);   summary(linear.post);
  #exponential regression
  exp.lm.post = lm(log(MinQ7) ~ (AnnualProb), data=low.flow.post); summary(exp.lm.post);

 #linear and exponential regressions have a similar r2. You can pick either one.
  y.est.post <- predict(linear.post,x.est, interval="confidence")
  	y.est.post <- as.data.frame(y.est.post)
  y.est.exp.post <- as.data.frame(exp(predict(exp.lm.post,x.est, interval="confidence")))
  
#What is the 7Q10 low flow value?
  low.7Q10.post <- predict(linear.post,filter(x.est,AnnualProb==10),interval="confidence"); 
  abline(h=low.7Q10.post[1], col=rgb(0.7,0.5,0), lty=2, lwd=2)
```



Let's plot the 7Q10 for the period of record with the 7Q10 after Falls Lake was constructed.

```R
#add original low flow value
  abline(h=low.7Q10[1], col="red", lty=4)
  points(low.flow$AnnualProb, low.flow$MinQ7, col=rgb(1,0,0,0.8), cex=0.6, pch=19)  

legend("top", c("Post Falls Lake Annual Low Flow", "Post Falls Lake 7Q10", "POR Annual Low Flow", "POR 7Q10"), col=c("goldenrod3","goldenrod3","red","red"),
       pch=c(19,NA,19,NA), lty=c(0,2,0,4))
```

Notice that the 7Q10 value has doubled. How much has the 7Q10 value increased?

```R
print(paste0("Min Flow increased by ", round((low.7Q10.post[1]-low.7Q10[1])/low.7Q10[1]*100,2), "%"))
```



##### Plot when low flow days have occurred using the 7Q10 following Falls Lake construction

```R
#plot low flow days
plot(neuse$Date, neuse$Flow_cms, type='n', yaxt="n", ylim=c(0,20),
     ylab="Streamflow (cms)", xlab = '')
axis(2, las=2, cex.axis=0.9)
lines(neuse$Date, neuse$Flow_cms, lwd=1, col=rgb(0,0,1,0.3))

#subset data to include only low flow exceedances
low.days.post <- subset(neuse, Flow_cms <= low.7Q10.post[1]); dim(low.days.post)
#Plot points and ablines
points(low.days.post$Date, low.days.post$Flow_cms, col=rgb(1,0,0,0.6), pch=19, cex=0.8)  
	abline(v=c(as.Date("1980-01-01"), as.Date("1984-01-01")), lty=2, col="black", lwd=3)
	abline(h=low.7Q10.post[1], col="red", lty=4)
#plot orginal data
points(low.days$Date, low.days$Flow_cms, col=rgb(0.7,0,0,0.6), pch=19)  
abline(h=low.7Q10[1], col="darkred", lty=4)
```



#### Create a return interval table summarizing your findings

```R
n.years.post <- length(unique(low.days.post$Year))
#create table
RI.table <- as.data.frame(matrix(nrow=2, ncol=5));    
#provide column names
colnames(RI.table) <- c("Date.Range", "7Q10_cms","No_Days","Annual_Prob","AdjustedR2")

#Fill in each column with the relevant data
  RI.table$Date.Range <- c("1930-2017","1984-2017")
  RI.table$`7Q10_cms` <- c(round(low.7Q10[1],3), round(low.7Q10.post[1],3))
  RI.table$No_Days <- c(n.years, n.years.post)
  RI.table$Annual_Prob <- c(round(n.years/length(unique(neuse$Year))*100,2),										round(n.years.post/length(unique(neuse$Year))*100,2))
  RI.table$AdjustedR2 <- c(summary(exp.lm)$adj.r.squared, summary(exp.lm.post)$adj.r.squared)

#View table
RI.table
```

