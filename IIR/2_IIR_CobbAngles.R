library(dplyr)
library(ggplot2)
library(tidyverse)
library(readr)
library(lme4)
library(lmerTest)
library(psych)
library(performance)
library(dplyr)
library(ggpubr)

cobbangles_all <- read_csv("IIRstudyCobbAngles.csv", col_names = TRUE)
cobbangles_all$isClin <- as.factor(cobbangles_all$isClin);
levels(cobbangles_all$isClin) <- c("student", "clinician");

cobbangles_clinicians <- cobbangles_all[cobbangles_all$isClin == "clinician",]
cobbangles_students <- cobbangles_all[cobbangles_all$isClin == "student",]

# check normality
hist(cobbangles_all$cobbAngle, breaks = c(0,9.99, 24.99, 44.99,60))
hist(cobbangles_all$refCobbAngle, breaks = c(0,9.99, 24.99, 44.99,60))
hist(cobbangles_all$error)
ggqqplot(cobbangles_all$cobbAngle)
ggqqplot(cobbangles_all$refCobbAngle)
ggqqplot(cobbangles_all$error)
shapiro.test(cobbangles_all$cobbAngle)
shapiro.test(cobbangles_all$refCobbAngle)
shapiro.test(cobbangles_all$error)


#Box plot cobb angle clin vs students
ggplot(cobbangles_all, aes(x = isClin, y = cobbAngle, fill=isClin)) +
  geom_boxplot() +
  stat_boxplot(geom ='errorbar') +
  theme_minimal() +
  labs(
    x = "", 
    y = "Cobb angle [°]",
    fill = "Rater Group") +
  scale_x_discrete(labels=c("students","clinicians"))
  

#Box plot cobb angle clin vs students
ggplot(cobbangles_all, aes(x = isClin, y = error, fill=isClin)) +
  geom_boxplot() +
  stat_boxplot(geom ='errorbar') +
  theme_minimal() +
  labs(
    x = "", 
    y = "Cobb angle error [°]",
    fill = "Rater Group") +
  scale_x_discrete(labels=c("students","clinicians"))


# Correlation analysis ----------------------------------------------------
#Clinicians
groundtruth <- cobbangles_clinicians$refCobbAngle
cobbanglesOnly_clinicians_cor<-cobbangles_clinicians$cobbAngle
correlation_coefficient <- cor(groundtruth, cobbanglesOnly_clinicians_cor, use="complete.obs")
print(correlation_coefficient)
cor_test <- cor.test(groundtruth, cobbanglesOnly_clinicians_cor)
print(cor_test)
ggplot(data.frame(groundtruth, cobbanglesOnly_clinicians_cor), aes(x=groundtruth, y=cobbanglesOnly_clinicians_cor)) +
  geom_point() +
  geom_smooth(method=lm) +
  labs(title=paste("Correlation: ", cor_test$estimate), 
                   " with p-value: ", cor_test$p.value, digits=5)

#Students
groundtruth<-cobbangles_students$refCobbAngle
cobbanglesOnly_students<-cobbangles_students$cobbAngle
#Correlation analysis
correlation_coefficient <- cor(groundtruth, cobbanglesOnly_students, use="complete.obs")
# Output the result
print(correlation_coefficient)
cor.test(groundtruth,cobbanglesOnly_students)
#SCatterplot
ggplot(data.frame(groundtruth, cobbanglesOnly_students), aes(x=groundtruth, y=cobbanglesOnly_students)) +
  geom_point() +
  geom_smooth(method=lm) +
  labs(title=paste("Correlation: ", cor_test$estimate), 
       " with p-value: ", cor_test$p.value, digits=5)

# Lmer ----------------------------------------------------
CobbangleError_lmer<-lmer(error ~ isClin + (1|raterID:isClin), data = cobbangles_all)
#summary(CobbangleError_lmer)
confint(CobbangleError_lmer, oldNames=FALSE)
CobbangleError_lmer<-lmer(error ~ as.factor(patID) + isClin + (1|raterID:isClin), data = cobbangles_all)
#summary(CobbangleError_lmer)
confint(CobbangleError_lmer, oldNames=FALSE)
Cobbangle_lmer<-lmer(cobbAngle ~ as.factor(patID) + isClin + (1|raterID:isClin), data = cobbangles_all)
#summary(Cobbangle_lmer)
confint(Cobbangle_lmer, oldNames=FALSE, level=0.9)

# ICC analysis ----------------------------------------------------
cobbangles_all_icc <- cobbangles_all[,c("patID", "repID", "raterID", "isClin", "cobbAngle")]

Cobbangle_lmer<-lmer(cobbAngle ~ (1|patID) + isClin + (1|raterID:isClin), data = cobbangles_all_icc)
performance::icc(Cobbangle_lmer, ci = TRUE)

# ICC - Intrarater

intraICCs = rep(NA,16)
intraICCs_l = rep(NA,16)
intraICCs_u = rep(NA,16)
for (ri in 1:10) {
# https://europepmc.org/article/MED/27330520 Two-way mixed effects, absolute agreement, single rater/measurement
  
  cobbangles_students_t <- cobbangles_students[cobbangles_students$raterID==ri,]
  cobbangles_students_t$patID <- as.factor(cobbangles_students_t$patID)
  cobbangles_students_t$repID <- as.factor(cobbangles_students_t$repID)
  cobbangles_students_t_ca1 <- cobbangles_students_t[cobbangles_students_t$repID==1,]$cobbAngle
  cobbangles_students_t_ca2 <- cobbangles_students_t[cobbangles_students_t$repID==2,]$cobbAngle
  cobbangles_students_t_ca3 <- cobbangles_students_t[cobbangles_students_t$repID==3,]$cobbAngle
  cobbangles_students_t_ca <- cbind(cobbangles_students_t_ca1,cobbangles_students_t_ca2,cobbangles_students_t_ca3)
  psicc <- psych::ICC(cobbangles_students_t_ca)
  intraICCs[ri] <- psicc$results[2,2]
  intraICCs_l[ri] <- psicc$results[2,7]
  intraICCs_u[ri] <- psicc$results[2,8]
}
for (ri in 1:6) {
  # https://europepmc.org/article/MED/27330520 Two-way mixed effects, absolute agreement, single rater/measurement
  
  cobbangles_clinicians_t <- cobbangles_clinicians[cobbangles_clinicians$raterID==ri,]
  cobbangles_clinicians_t$patID <- as.factor(cobbangles_clinicians_t$patID)
  cobbangles_clinicians_t$repID <- as.factor(cobbangles_clinicians_t$repID)
  cobbangles_clinicians_t_ca1 <- cobbangles_clinicians_t[cobbangles_clinicians_t$repID==1,]$cobbAngle
  cobbangles_clinicians_t_ca2 <- cobbangles_clinicians_t[cobbangles_clinicians_t$repID==2,]$cobbAngle
  cobbangles_clinicians_t_ca3 <- cobbangles_clinicians_t[cobbangles_clinicians_t$repID==3,]$cobbAngle
  cobbangles_clinicians_t_ca <- cbind(cobbangles_clinicians_t_ca1,cobbangles_clinicians_t_ca2,cobbangles_clinicians_t_ca3)
  psicc <- psych::ICC(cobbangles_clinicians_t_ca)
  intraICCs[ri+10] <- psicc$results[2,2]
  intraICCs_l[ri+10] <- psicc$results[2,7]
  intraICCs_u[ri+10] <- psicc$results[2,8]
}
median(intraICCs)
IQR(intraICCs)
median(intraICCs_l)
IQR(intraICCs_l)
median(intraICCs_u)
IQR(intraICCs_u)

#PLOTS
ggplot(cobbangles_clinicians, aes(x = raterID, y = cobbAngle, group=raterID, color = factor(raterID))) +
  theme_minimal() +
  geom_point()+
  labs(title = paste("ICC=", round(piccClin$results$ICC[2], digits=2)),
       x = "",
       y = "Cobb Angle [°]",
       fill = "Rater ID")+
  theme(plot.title = element_text(hjust = 0.5))
ggplot(cobbangles_students, aes(x = raterID, y= cobbAngle, group=raterID, color = factor(raterID))) +
  theme_minimal() +
  geom_point()+
  labs(title = paste("ICC=", round(piccStud$results$ICC[2],digits=2)),
       x = "",
       y = "Cobb Angle [°]",
       fill = "Rater ID")+
  theme(plot.title = element_text(hjust = 0.5)) 

# equivalence - https://pedermisager.org/blog/mixed_model_equivalence/

bound_u <-  5  # Upper equivalence bound
bound_l <- -5  # Lower equivalence bound
lower <- contest1D(CobbangleError_lmer, c(0,1), confint=TRUE, rhs=bound_l) # get t value for test against lower bound
upper <- contest1D(CobbangleError_lmer, c(0,1), confint=TRUE, rhs=bound_u) # get t value for test against upper bound
lower
upper