#
#   Modifications to structure/values of tables from httk package introduced by LASER
#

#load in raw file:
load("inst/extdata/Tables.Rdata")


#modifications of the table structure for Vmax and km params...
# adding mock values for Chlorpyrifos everywhere for testing
    chem.physical_and_invitro.data$Human.Vmax <- NA
    chem.physical_and_invitro.data$Human.km <- NA
    chem.physical_and_invitro.data$Rat.Vmax <- NA
    chem.physical_and_invitro.data$Rat.km <- NA
    chem.physical_and_invitro.data$Vmax.Reference <- NA
    chem.physical_and_invitro.data$km.Reference <- NA
    #test of updating values (to be done via csv edit later)
    chem.physical_and_invitro.data[chem.physical_and_invitro.data$Compound=="Chlorpyrifos","Human.km"] <- 2.15
    chem.physical_and_invitro.data[chem.physical_and_invitro.data$Compound=="Chlorpyrifos","Human.Vmax"] <- 5.66

#...and for FR, KTS parameters (renal clearance)
    chem.physical_and_invitro.data$Human.FR <- NA
    chem.physical_and_invitro.data$Rat.FR <- NA
    chem.physical_and_invitro.data$FR.Reference <- NA
    chem.physical_and_invitro.data[chem.physical_and_invitro.data$Compound=="Chlorpyrifos","Human.FR"] <- 0
    chem.physical_and_invitro.data[chem.physical_and_invitro.data$Compound=="Chlorpyrifos","Rat.FR"] <- 0
    
    chem.physical_and_invitro.data$Human.KTS <- NA
    chem.physical_and_invitro.data$Rat.KTS <- NA
    chem.physical_and_invitro.data$KTS.Reference <- NA
    chem.physical_and_invitro.data[chem.physical_and_invitro.data$Compound=="Chlorpyrifos","Human.KTS"] <- 1
    chem.physical_and_invitro.data[chem.physical_and_invitro.data$Compound=="Chlorpyrifos","Rat.KTS"] <- 1
    
    
#modifications of physiology.data to allow for CV:
#for now off!
    # physiology.sd.data <- data.frame(lapply(physiology.data, 
    #                                         function(x) {
    #                                             if(class(x)=="numeric") { return(x*0.05) 
    #                                             } else { return(x) }
    #                                         }
    # ))


#save all tables post-update:
# save(chem.invivo.PK.data, file="data/chem.invivo.PK.data.Rdata")
# save(chem.invivo.PK.summary.data, file="data/chem.invivo.PK.summary.data.Rdata")
# save(chem.physical_and_invitro.data, file="data/chem.physical_and_invitro.data.Rdata")
# save(physiology.data, file="data/physiology.data.Rdata")
# save(tissue.data, file="data/tissue.data.Rdata")
# save(Wetmore.data, file="data/Wetmore.data.Rdata")
devtools::use_data(chem.invivo.PK.data, chem.invivo.PK.summary.data, chem.physical_and_invitro.data, 
                   physiology.data, tissue.data, Wetmore.data,
                   overwrite = TRUE)

