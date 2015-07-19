####
if(Sys.info()["user"]=="janus829" | Sys.info()["user"]=="s7m"){
	source('~/Research/RemmerProjects/disputesReputation/RCode/setup.R') }
####

###############################################################
# Load in datasets
dvData='icrg.rda'
monData=c('disputes', 'kaopen', 'constraints', 'polity', 'worldBank', 'bitPanel') %>% paste0('.rda')
dyData=c('distMats') %>% paste0('.rda')
###############################################################

###############################################################
# Merge monadic variables from icrg, worldBank, polity, constraints into kaopen
for(pkg in pathBin %>% paste0(c(dvData, monData)) ) { load( pkg ) }; rm(list='pkg')

# Merge disputes
disputes = disputes[,c('cyear', names(disputes)[9:40])]
aData = merge(icrg, disputes, by='cyear', all.x=TRUE, all.y=FALSE)

# Merge kaopen
kaopen = kaopen[,c('cyear', 'kaopen', 'ka_open')]
aData = merge(aData, kaopen, by='cyear', all.x=TRUE, all.y=FALSE)

# Merge worldbank
aData = merge(aData, worldBank, by='cyear', all.x=TRUE, all.y=FALSE)

# Merge polity
polity = polity[,c('cyear', names(polity)[8:21])]
aData = merge(aData, polity, by='cyear', all.x=TRUE, all.y=FALSE)

# Merge constraints
constraints = constraints[,c('cyear', names(constraints)[8:10])]
aData = merge(aData, constraints, by='cyear', all.x=TRUE, all.y=FALSE)

# Merge BITs
bitPanel$cyear = paste0(bitPanel$ccode, bitPanel$year)
bitPanel = bitPanel[,c('cyear', names(bitPanel)[7:18])]
aData = merge(aData, bitPanel, by='cyear', all.x=TRUE, all.y=FALSE)

# Remove leftover datasets
rm(list=c(substr(dvData, 1, nchar(dvData)-4),
	substr(monData, 1, nchar(monData)-4)) )
###############################################################

###############################################################
# Create spatial variables
for(pkg in pathBin %>% paste0(dyData) ) { load( pkg ) }; rm(list='pkg')

# Turn non-diagonal zero entries in min distance matrices to 1
minMats2 = lapply(minMats, function(x){ x = x + 1; diag(x) = 0; x; })
names(minMats2) = names(minMats)

# Add 2013 to distance matrices (just repeating 2012)
capMats$'2013' = capMats$'2012'; capMats$'2014' = capMats$'2012'
centMats$'2013' = centMats$'2012'; centMats$'2014' = centMats$'2012'
minMats2$'2013' = minMats2$'2012'; minMats2$'2014' = minMats2$'2012'

# Create logged entries for each
capMatsL = lapply(capMats, function(x) { log(x + 1) })
centMatsL = lapply(centMats, function(x) { log(x + 1) })
minMats2L = lapply(minMats2, function(x) { log(x + 1) })

# Create spatial version of kaopen vars
vars = c('invProf','fdi', 'rfdi', 'fdiLog', 'rfdiLog')
wgtMats = list( 
	cap=capMats, cent=centMats, min=minMats2,
	capL=capMatsL, centL=centMatsL, minL=minMats2L
	)
spNames = names(wgtMats) %>% paste0('_')
years = lapply(wgtMats, names)
inv = rep(TRUE, length(wgtMats))

# Check to make sure right mats are being inverted
cbind(names(wgtMats), inv) %>% print()

for(ii in 1:length(wgtMats)){
	spData = spatialBuild(spatList=wgtMats[[ii]],
		varData=aData, years=1984:2014, variable=vars,
		sp_suffix=spNames[ii], invert=inv[ii] )
	spData$cyear = num(spData$cyear)
	aData = merge(aData, 
		spData[,c(1:length(vars),ncol(spData))],by='cyear',all.x=T)
	print(spNames[ii])	}
###############################################################

###############################################################
# Create lags

# Select vars to lag
noLag = c( 'cyear','Country', 'year', 'cname', 'ccode', 'cnameYear' )
toLag = setdiff(names(aData), noLag)

# Adjustments to id variables
aData$cyear = num(aData$cyear)
aData$ccode = num(aData$ccode)

# Make sure all variables to be lagged are numeric
sum(apply(aData[,toLag],2,class)=='numeric')/length(toLag)

# Lag selected variables 1 year
aData = lagDataSM(aData, 'cyear', 'ccode', toLag, lag=1)
###############################################################

###############################################################
# Save
save(aData, file=paste0(pathBin,'analysisData.rda'))
###############################################################