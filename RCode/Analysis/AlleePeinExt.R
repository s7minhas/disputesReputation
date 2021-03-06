# Setting workspace
source('~/Research/disputesReputation/RCode/setup.R')

# Load remmer/minhas data
load(paste0(pathData, '/apExt.rda'))

# Set up model specifications
getForm = function(dispIVs, other=ctrls, FE=''){
	forms = lapply(dispIVs, function(x){
		formula( 
			paste0( dv[4], ' ~ ', 
				paste0( 
					paste(c(x,other), collapse=' + '), FE
					) # add fixed effects
				) # Add ivs
			) # convert to formula
		}) # close lapply
	return(forms)
}
form2YrFE = getForm(ivDisp2, FE='+ factor(ccode)-1')
form5YrFE = getForm(ivDisp5, FE='+ factor(ccode)-1')

# Run fixed effect models
mod2YrFE = lapply(form2YrFE, function(f){ lm(f, data=modelData) })
mod5YrFE = lapply(form5YrFE, function(f){ lm(f, data=modelData) })

lapply(mod2YrFE, function(x) {coeftest(x)[1,,drop=FALSE]}) %>% do.call('rbind', .)
lapply(mod5YrFE, function(x) {coeftest(x)[1,,drop=FALSE]}) %>% do.call('rbind', .)

