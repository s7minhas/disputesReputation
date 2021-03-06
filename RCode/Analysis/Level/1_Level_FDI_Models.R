#######################################################################################
if(Sys.info()["user"]=="janus829" | Sys.info()["user"]=="s7m"){
	source('~/Research/disputesReputation/RCode/setup.R') }

### Load data
load(paste0(pathBin, 'analysisData.rda'))
#######################################################################################

#######################################################################################
# Setting up models
aData$fdiLog2 = logNeg(aData$fdi) ; dv='fdiLog2'

# disputes
dispVars =  c( 'iDispB')
dispLabs = c('ICSID' )
ivDisp=c( paste0('mvs2_',dispVars), paste0('mvs5_',dispVars), paste0(dispVars, 'C') )
ivDispName = c( dName(dispLabs,2), dName(dispLabs,5), dName(dispLabs) )

# Other covariates
ivOther=c(
	'gdpGr', 'gdpCapLog', 'popLog','inflLog',
	'intConf', 'extConf',
	'rbitNoDuplC', 'kaopen', 'polity', 'propRights'
	)
ivs=c(ivDisp, ivOther)
ivAll=lapply(ivDisp, function(x) FUN= c( lagLab(x,1), lagLab(ivOther,1), 'globSumRFDI' ) )

# Setting up variables names for display
ivOtherName=c(
	'\\%$\\Delta$ GDP', 'Ln(GDP per capita)', 'Ln(Pop.)', 'Ln(Inflation)', 
	'Internal Stability','External Stability',
	'Ratified BITs','Capital Openness','Polity', 'Property Rights'
	)
ivsName=lapply(1:length(ivDispName), function(x){ c(ivDispName[x], lagLabName(ivOtherName), 'World FDI') })
#######################################################################################

#######################################################################################
# Simple mod analysis
# By country
getInts = function(res){ 
	c(mu=res[1], hi95=res[1]+qnorm(.975)*res[2], lo95=res[1]-qnorm(.975)*res[2],
		hi90=res[1]+qnorm(.95)*res[2], lo90=res[1]-qnorm(.95)*res[2] )  }
cntries = char( unique(aData$ccode) )
mat = matrix(NA, nrow=length(cntries), ncol=length(ivDisp), dimnames=list(cntries, ivDisp))
csMods = list(rho=mat, mu=mat, hi95=mat, lo95=mat, hi90=mat, lo90=mat)
for(c in cntries){
	slice = aData[aData$ccode==c,]
	for(d in ivDisp){
		if( sum(slice[,d], na.rm=TRUE)>1 ){
			dForm = paste(dv, lagLab(d, 1), sep='~') %>% formula()
			cdCoef = lm(dForm, data=slice) %>% coeftest() %>% .[2,1:2] ; names(cdCoef) = NULL; cdCoef = getInts(cdCoef)
			rho = cor(slice[,c(dv, d)], method='pearson')[1,2]
			csMods[['rho']][c,d] = rho ;csMods[['mu']][c,d] = cdCoef['mu'] ; csMods[['hi95']][c,d] = cdCoef['hi95'] 
			csMods[['lo95']][c,d] = cdCoef['lo95']; csMods[['hi90']][c,d] = cdCoef['hi90'] ; csMods[['lo90']][c,d] = cdCoef['lo90']
		}
	}
}
tmp = lapply(csMods, function(x){ melt(x) %>% mutate(., id=paste0(X1, X2)) %>% na.omit() %>% return(.) })
ggCoef = tmp[['mu']]
for(v in c('rho', as.vector(outer(c('hi','lo'), c('95','90'), paste0)))){
	ggCoef$tmp = tmp[[v]][,3][match(ggCoef$id, tmp[[v]][,4] )] ; names(ggCoef)[ncol(ggCoef)] = v }

# Calculate for full sample using fixed effects & rbind
fullID='All'
fullCoef = lapply(ivDisp, function(d){
	dForm = paste0(paste(dv, lagLab(d,1), sep='~'), ' + factor(ccode)-1') %>% formula()
	dCoef = lm(dForm, data=aData) %>% coeftest() %>% .[1,1:2] ; names(dCoef) = NULL; dCoef = getInts(dCoef) ; names(dCoef)[1] = ''
	rho = cor(aData[,c(dv,d)], method='pearson', use='complete.obs')[1,2]
	c(X1=fullID, X2=d, value=dCoef[1], id=paste0(fullID,d), rho=rho, dCoef[2:length(dCoef)])
	}) %>% do.call('rbind', .) %>% data.frame()
for(v in names(fullCoef)[!names(fullCoef) %in% c('X1', 'X2', 'id')]){ fullCoef[,v] = num(fullCoef[,v]) }
ggCoef$fixefValue = fullCoef$value[match(ggCoef$X2, fullCoef$X2)]

# Adjust var names
ggCoef$X2 = mapVar(ggCoef$X2, ivDisp, ivDispName)
ggCoef$cntry = panel$CNTRY_NAME[match(ggCoef$X1, panel$ccode)] ; ggCoef$cntry[ggCoef$X1==fullID] = fullID
ggCoef$cAbb = countrycode(ggCoef$cntry, 'country.name', 'cowc') ; ggCoef$cAbb[ggCoef$X1==fullID] = fullID
ggCoef$cAbb = factor(ggCoef$cAbb, levels=c(char(sort(unique(ggCoef$cAbb[ggCoef$cAbb!=fullID]))), fullID))

# viz
tmp=ggplot(ggCoef, aes(x=value)) +
	geom_histogram(bins=80, fill='#bdbdbd', color='#969696') +
	geom_vline(xintercept=0, color='red', linetype='solid') +
	scale_x_continuous('$\\beta$ for Dispute Variables', expand = c(0, 0)) +
	scale_y_continuous('Count',expand = c(0, 0), labels=seq(0,20,5), limits=c(0,20)) +
	facet_wrap(~X2, nrow=1, scales='free_x') +
	theme(
			legend.position='none',
			legend.title=element_blank(),
		    axis.ticks=element_blank(),
		    panel.border=element_blank()
    )
# tikz(file=paste0(pathLatex, '/corrFDI.tex'),width=8,height=3.5,standAlone=F)
# tmp
# dev.off()

countNeg = function(x, neg=TRUE){ 
	if(neg){ return( length(x[x<0]) ) }
	if(!neg){ return( length(x[x>0]) ) } }
summaryBy(value ~ X2, FUN=countNeg, data=ggCoef, neg=TRUE)
summaryBy(value ~ X2, FUN=countNeg, data=ggCoef, neg=FALSE)
#######################################################################################

#######################################################################################
# Running fixed effect models with plm
plmData=pdata.frame( aData[,c(dv, unique(unlist(ivAll)), 'ccode', 'year') ], index=c('ccode','year') )
modForm=lapply(ivAll, function(x){
	as.formula( paste(dv,  paste(x, collapse=' + '), sep=' ~ ')) })
modResults=lapply(modForm, function(x) FUN=plm(x, data=plmData, model='within') )
modSumm=lapply(modResults, function(x){
	coeftest(x)[,c('Estimate','Std. Error', 't value', 'Pr(>|t|)')] })
#######################################################################################

#######################################################################################
# Creating APSR like tables
fileTable='LfeResultsFDI.tex'
captionTable='Fixed effects regression on Ln(FDI flows) with standard errors in parentheses. $^{**}$ and $^{*}$ indicate significance at $p< 0.05 $ and $p< 0.10 $, respectively.'
varDef = cbind( unique(unlist(ivAll)),  unique(unlist(ivsName)) )
varDef = varDef[c(1,nrow(varDef)-1,nrow(varDef),2:(nrow(varDef)-2)),]

digs=3; noModels=length(modSumm)
tableResults = matrix('', nrow=2*length(varDef[,1]), ncol=1+noModels)
tableResults[,1] = rep(varDef[,1],2)
colnames(tableResults) = c('Variable','Model 1', 'Model 2', 'Model 3')
for(ii in 2:ncol(tableResults)){
	temp = modSumm[[ii-1]]
	n = modResults[[ii-1]]$df.residual
	temp = temp[match(tableResults[,'Variable'], rownames(temp)),]
	estims = temp[1:nrow(varDef),'Estimate']
	estims = round(as.numeric(as.character(estims)),digs)
	tvals = abs(temp[1:nrow(varDef),'t value'])
	tvals = round(as.numeric(as.character(tvals)),digs)
	estims = ifelse(tvals>=qt(0.975,n) & !is.na(tvals) & tvals<qt(0.995,n), 
		paste('$', estims,'^{\\ast}$',sep=''), estims)
	estims = ifelse(tvals>=qt(0.995,n) & !is.na(tvals), 
		paste('$', estims,'^{\\ast\\ast}$',sep=''), estims)	
	estims = ifelse(is.na(estims),'',estims)
	tableResults[1:nrow(varDef),ii] = estims
	serrors = temp[(nrow(varDef)+1):nrow(tableResults),'Std. Error']
	serrors = round(as.numeric(as.character(serrors)),digs)
	serrors = paste('(',serrors,')',sep='')
	serrors = ifelse(serrors=='(NA)','',serrors)
	tableResults[(nrow(varDef)+1):nrow(tableResults),ii] = serrors
}

# Reorganizing rows and variable labels
tableFinal = NULL
for(ii in 1:nrow(varDef)){
	temp = cbind('', t(tableResults[ii+nrow(varDef),2:ncol(tableResults)]))
	tableFinal = rbind(tableFinal, tableResults[ii,], temp) }

# Adding other info
sSize = cbind('n', t(as.vector(mapply(x=modResults, 
	function(x) FUN=length(x$residuals)))))
gSize = cbind('N', t(as.vector(mapply(x=modResults, 
	function(x) FUN=length(x$residuals)-x$df.residual-length(x$coefficient)))))
rSQ = cbind('$R^{2}$', t(as.vector(mapply(x=modResults,
		function(x) FUN=round(summary(x)$r.squared[1],2) ))))
arSQ = cbind('Adj. $R^{2}$', t(as.vector(mapply(x=modResults,
		function(x) FUN=round(summary(x)$r.squared[2],2) ))))
rmse = round(mapply(x=modResults, function(x) FUN=sqrt(mean(x$residuals^2))),2)
fRmse = cbind('RMSE', t(rmse))
tableFinal = rbind(tableFinal, sSize, gSize, rSQ, arSQ, fRmse)
nStats=5
temp=varDef[match(tableFinal[,'Variable'], varDef[,1]),2]
temp[which(is.na(temp))]=tableFinal[,'Variable'][which(is.na(temp))]
tableFinal[,'Variable']=temp

# Add & before every period
tableFinal[,2:ncol(tableFinal)]=apply(tableFinal[,2:ncol(tableFinal)], c(1,2), 
	function(x){ 
		if( grepl('\\$', x) ){ gsub('\\$*\\.', '$&$.', x)
		} else { gsub('\\.', '&.', x) } })

print.xtable(xtable(tableFinal, align='llccc', caption=captionTable),
	include.rownames=FALSE,
	sanitize.text.function = identity,
	hline.after=c(0,0,nrow(varDef)*2,nrow(varDef)*2+nStats,nrow(varDef)*2+nStats),
	size="footnotesize",	
	file=paste0(pathLatex, '/', fileTable) )
#######################################################################################

#######################################################################################
# fix up r squared
modForm=lapply(ivAll, function(x){
	as.formula( paste0(paste(dv,  paste(x, collapse=' + '), sep=' ~ '), ' + factor(ccode) - 1')) })
modResults=lapply(modForm, function(x) FUN=lm(x, data=aData) )
lapply(modResults, function(x){
	c(summary(x)$'r.squared', summary(x)$'adj.r.squared') })
#######################################################################################

#######################################################################################
# Coefficient plot
# add conf ints
ggCoefData = lapply(modSumm, function(x){
	hi95 = x[,1] + qnorm(.975)*x[,2]
	lo95 = x[,1] - qnorm(.975)*x[,2]
	hi90 = x[,1] + qnorm(.95)*x[,2]
	lo90 = x[,1] - qnorm(.95)*x[,2]
	x = data.frame( cbind(x, hi95, lo95, hi90, lo90) )
	x$var = varDef[,2][match(rownames(x), varDef[,1])]
	x$mod = x$var[1]
	x$var[1] = 'ICSID'
	return(x) })

ggCoefData = do.call('rbind', ggCoefData)
ggCoefData$var = factor(ggCoefData$var, levels=rev(c('ICSID', varDef[,2][-(1:3)])))
ggCoefData$sig = NULL
ggCoefData$sig[ggCoefData$lo90 > 0 & ggCoefData$lo95 < 0] = "Positive at 90"
ggCoefData$sig[ggCoefData$lo95 > 0] = "Positive"
ggCoefData$sig[ggCoefData$hi90 < 0 & ggCoefData$hi95 > 0] = "Negative at 90"
ggCoefData$sig[ggCoefData$hi95 < 0] = "Negative"
ggCoefData$sig[ggCoefData$lo90 < 0 & ggCoefData$hi90 > 0] = "Insig"
coefp_colors = c("Positive"=rgb(54, 144, 192, maxColorValue=255), 
                "Negative"= rgb(222, 45, 38, maxColorValue=255),
                "Positive at 90"=rgb(158, 202, 225, maxColorValue=255), 
                "Negative at 90"= rgb(252, 146, 114, maxColorValue=255),
                "Insig" = rgb(150, 150, 150, maxColorValue=255))

coefp = ggplot(ggCoefData, aes(x=factor(var), y=Estimate, color=sig)) +
	geom_linerange(aes(ymin=lo95, ymax=hi95), alpha = .3, size = 0.3) +
	geom_linerange(aes(ymin=lo90, ymax=hi90),alpha = 1, size = 1) +
	geom_hline(aes(yintercept=0), linetype=2, color = "black") +
	geom_point(size=4, shape=20) +
	geom_errorbar(aes(ymin=lo95,ymax=hi95),linetype = 1,width = 0.1) +
	facet_wrap(~mod, nrow=1) +
	scale_colour_manual(values = coefp_colors) +
	coord_flip() + xlab('') + ylab('') +
	theme(
		legend.position='none',
		panel.grid = element_blank(), axis.ticks=element_blank()
		)
tikz(file=paste0(pathLatex, '/coefpFDI.tex'),width=8,height=6,standAlone=F)
coefp
dev.off()
#######################################################################################