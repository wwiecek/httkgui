# This function parameterizes a PBPK model. The argument tissuelist allows the specific tissues parameerized to be customized.
# All tissues not specified by tissuelist are lumped into a rest of body compartment ("Rest")

# LASER modification adds monte.carlo option, which indicates use of CV columns (for now for physiology.data)
# if monte.carlo = TRUE the 1st step after loading in data is going to be draw values at random, using provided CV
# qrenal option allows to replace GFR with (GFR + tubular secretion (TS) – tubular reabsorption (TR))

parameterize_pbtk <- function(chem.cas = NULL,
                              chem.name = NULL,
                              species = "Human",
                              default.to.human = F,
                              tissuelist=list(liver=c("liver"),kidney=c("kidney"),lung=c("lung"),gut=c("gut")),
                              force.human.clint.fub = F,
                              clint.pvalue.threshold = 0.05,
                              use.qrenal = F,
                              monte.carlo = TRUE,
                              monte.carlo.cv = NULL) {
    
  physiology.data <- physiology.data
  
  if(monte.carlo) {
      if(is.null(monte.carlo.cv)) monte.carlo.cv <- c("Total Body Water" = .3,
                                                      "Plasma Volume" = .3,
                                                      "Cardiac Output" = .3,
                                                      "Average BW" = .16, 
                                                      "Total Plasma Protein" = .14,
                                                      "Plasma albumin"= .1,
                                                      "Plasma a-1-AGP"= .3,
                                                      "Hematocrit"= .3,
                                                      "Urine"= .3,
                                                      "Bile"= .3,
                                                      "GFR"=.3,
                                                      "Average Body Temperature" = 0)
      physiology.data <- introduce_variability(input.mean = physiology.data, cv = monte.carlo.cv)
  }
# Look up the chemical name/CAS, depending on what was provide:
  out <- get_chem_id(chem.cas=chem.cas,chem.name=chem.name)
  chem.cas <- out$chem.cas
  chem.name <- out$chem.name
   
  if(class(tissuelist)!='list') stop("tissuelist must be a list of vectors.") 
  
  # Clint has units of uL/min/10^6 cells
  Clint <- try(get_invitroPK_param("Clint",species,chem.CAS=chem.cas),silent=T)
  if ((class(Clint) == "try-error" & default.to.human) || force.human.clint.fub) 
  {
    Clint <- try(get_invitroPK_param("Clint","Human",chem.CAS=chem.cas),silent=T)
    warning(paste(species,"coerced to Human for metabolic clerance data."))
  }
  if (class(Clint) == "try-error") stop("Missing metabolic clearance data for given species. Set default.to.human to true to substitute human value.")
  
  #try to grab Vmax and km - if they're available, use them instead of Clint
  Vmax <- try(get_invitroPK_param("Vmax", species, chem.CAS=chem.cas), silent=TRUE)
  km <- try(get_invitroPK_param("km", species, chem.CAS=chem.cas), silent=TRUE)
  #in case we're using qrenal instead of GFR, grab FR and give error if it's missing:
  if(use.qrenal) {
      FR <- try(get_invitroPK_param("FR", species, chem.CAS=chem.cas), silent=TRUE)
      if(class(FR) == "try-error") stop("Attempting to use renal clearance flow, but FR parameter value is missing.")
      KTS <- try(get_invitroPK_param("KTS", species, chem.CAS=chem.cas), silent=TRUE)
      if(class(KTS) == "try-error") stop("Attempting to use renal clearance flow, but KTS parameter value is missing.")
  }
  if((class(km) != "try-error") && (class(Vmax) != "try-error"))
      Clint <- Vmax/km
  
  # Check that the trend in the CLint assay was significant:
  Clint.pValue <- get_invitroPK_param("Clint.pValue",species,chem.CAS=chem.cas)
  if (!is.na(Clint.pValue) & Clint.pValue > clint.pvalue.threshold) Clint <- 0
  
  # unitless fraction of chemical unbound with plasma
  fub <- try(get_invitroPK_param("Funbound.plasma",species,chem.CAS=chem.cas),silent=T)
  if ((class(fub) == "try-error" & default.to.human) || force.human.clint.fub) 
  {
    fub <- try(get_invitroPK_param("Funbound.plasma","Human",chem.CAS=chem.cas),silent=T)
    warning(paste(species,"coerced to Human for protein binding data."))
  }
  if (class(fub) == "try-error") stop("Missing protein binding data for given species. Set default.to.human to true to substitute human value.")
  if (fub == 0)
  {
    fub <- 0.005
    warning("Fraction unbound = 0, changed to 0.005.")
  }
  
  Fgutabs <- try(get_invitroPK_param("Fgutabs",species,chem.CAS=chem.cas),silent=T)
  if (class(Fgutabs) == "try-error") Fgutabs <- 1
    
  
 # Check the species argument for capitilization problems and whether or not it is in the table:  
  if (!(species %in% colnames(physiology.data)))
  {
    if (toupper(species) %in% toupper(colnames(physiology.data)))
    {
      phys.species <- colnames(physiology.data)[toupper(colnames(physiology.data))==toupper(species)]
    } else stop(paste("Physiological PK data for",species,"not found."))
  } else phys.species <- species

# Load the physiological parameters for this species
  this.phys.data <- physiology.data[,phys.species]
  names(this.phys.data) <- physiology.data[,1]
  
  temp <- this.phys.data[['Average Body Temperature']] 
# Load the physico-chemical properties:  
  MW <- get_physchem_param("MW",chem.CAS=chem.cas) #g/mol
  pKa_Donor <- suppressWarnings(get_physchem_param("pKa_Donor",chem.CAS=chem.cas))
  pKa_Accept <- suppressWarnings(get_physchem_param("pKa_Accept",chem.CAS=chem.cas))
  Pow <- 10^get_physchem_param("logP",chem.CAS=chem.cas)
  MA <- suppressWarnings(10^(get_physchem_param("logMA",chem.CAS=chem.cas)))
  
# Predict the PCs for all tissues in the tissue.data table:
  parm <- list(Funbound.plasma=fub,Pow=Pow,pKa_Donor=pKa_Donor,pKa_Accept=pKa_Accept,MA=MA,Fprotein.plasma = 75/1000/1.025,plasma.pH=7.4,temperature=temp)
  PCs <- predict_partitioning_schmitt(parameters=parm)
# Get_lumped_tissues returns a list with the lumped PCs, vols, and flows:
  lumped_params <- lump_tissues(PCs,tissuelist=tissuelist,species=species)


  outlist <- list()
   # Begin flows:
  #mL/min/kgBW converted to L/h/kgBW:
  QGFRc <- this.phys.data[["GFR"]]/1000*60
  Qcardiacc <- this.phys.data["Cardiac Output"]/1000*60 
  flows <- unlist(lumped_params[substr(names(lumped_params),1,1) == 'Q'])
  
  # LASER update: consider renal clearance flow instead
    if(use.qrenal)
        QGFRc <- fub*QGFRc + (flows[["Qkidneyf"]] - fub*QGFRc)*(1-exp(- (fub*QGFRc * KTS/(flows[["Qkidneyf"]]-QGFRc)) ))*(1 - FR)
    #                                                  

  outlist <- c(outlist,c(
    Qcardiacc = as.numeric(Qcardiacc),
    flows[!names(flows) %in% c('Qlungf','Qtotal.liverf')],
    Qliverf= flows[['Qtotal.liverf']] - flows[['Qgutf']],
    Qgfrc = QGFRc
  ))
  # end flows  
  
                                                      
  # Begin volumes
  # units should be L/kgBW  
  Vartc = this.phys.data["Plasma Volume"]/(1-this.phys.data["Hematocrit"])/2/1000 #L/kgBW
  Vvenc = this.phys.data["Plasma Volume"]/(1-this.phys.data["Hematocrit"])/2/1000 #L/kgBW

  outlist <- c(outlist,
    Vartc = as.numeric(Vartc),
    Vvenc = as.numeric(Vvenc),
    lumped_params[substr(names(lumped_params),1,1) == 'V'],
    lumped_params[substr(names(lumped_params),1,1) == 'K'])
  
  
# Create the list of parameters:
  BW <- this.phys.data["Average BW"]
  hematocrit = this.phys.data["Hematocrit"]
  outlist <- c(outlist,list(BW = as.numeric(BW),
    kgutabs = 1, # 1/h
    kinhabs = 1, # 1/h
    kdermabs = 1, # 1/h
    Funbound.plasma = as.numeric(fub), # unitless fraction
    hematocrit = as.numeric(hematocrit), # unitless ratio
    MW = MW)) #g/mol
  
  # Correct for unbound fraction of chemical in the hepatocyte intrinsic clearance assay (Kilford et al., 2008)
 outlist <- c(outlist,list(Fhep.assay.correction=calc_fu_hep(Pow,pKa_Donor=pKa_Donor,pKa_Accept=pKa_Accept)))  # fraction 

  outlist <- c(outlist,
    list(Clmetabolismc= as.numeric(calc_hepatic_clearance(hepatic.model="unscaled",parameters=list(
                                Clint=Clint, #uL/min/10^6 cells
                                Funbound.plasma=fub, # unitless fraction
                                Fhep.assay.correction=outlist$Fhep.assay.correction, 
                                million.cells.per.gliver= 110, # 10^6 cells/g-liver
                                liver.density= 1.05, # g/mL
                                Dn=0.17,BW=BW,
                                Vliverc=lumped_params$Vliverc, #L/kg
                                Qtotal.liverc=(lumped_params$Qtotal.liverc)/1000*60),suppress.messages=T)),million.cells.per.gliver=110,Fgutabs=Fgutabs)) #L/h/kg BW
  
    outlist <- c(outlist,Rblood2plasma=as.numeric(1 - hematocrit + hematocrit * PCs[["Krbc2pu"]] * fub))
  return(outlist[sort(names(outlist))])
}