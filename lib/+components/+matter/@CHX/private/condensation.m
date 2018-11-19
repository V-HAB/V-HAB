function [sCondensableFlowRateCell, fOutlet_Temp_Hot_New, acCondensateNames, fCondensateHeatFlow] = condensation ...
         (oHX, afCondensableFlowRate, fHeat_Capacity_Flow_Hot, fHeatFlow, fTwall, fOutlet_Temp_Hot, fEntry_Temp_Hot, oFlow_Hot, iIncrements)
     
%condensation is a function that calculates what substance condenses in the
%heat exchanger, how much mass flow of condensate is generated and what the
%new outlet temperature has to be. The function is built into the CHX_main
%function and it shoult not be necessary for a user to work with it. But in
%case someone has to change something here the different input and output
%values are explained in the following section.
%
%the input values for this function are 
%(oHX, sCondensableFlowRate, fHeat_Capacity_Flow_Hot, fHeatFlow, fTwall, fOutlet_Temp_Hot, fEntry_Temp_Hot, oFlow_Hot, fBoundaryFlowRatio)
%	oHX: has to be a condensing heat exchanger object )it is automatically
%        defined in the CHX_main function.
%   sCondensableFlowRate: a struct containing the AVAILABLE mass of
%   condensate for each substance, therefore the values in here represent
%   the maximum amount of condensate that can be produced
%
%   the other input variables should be clear from their naming alone. It
%   is only important to realise that they are all for the hotter fluid
%   which is cooled down because this is where condensation takes place
     
fHeatFlow = abs(fHeatFlow);

if nargin < 9
    iIncrements = 1;
elseif iIncrements <= 0
    error('less than 1 increment is not possible for the condensation calculation, please check the inputs');    
end

%in case that the flow for which the condensation function is called is
%already a liquid nothing happens
if (oFlow_Hot.fFlowRate >= 0) && strcmp(oFlow_Hot.oBranch.coExmes{1,1}.oPhase.sType , 'liquid')
    sCondensableFlowRateCell =struct();
    fOutlet_Temp_Hot_New = fOutlet_Temp_Hot;
    acCondensateNames = '';
    fCondensateHeatFlow = 0;
    return
elseif (oFlow_Hot.fFlowRate < 0) && strcmp(oFlow_Hot.oBranch.coExmes{2,1}.oPhase.sType , 'liquid')
    sCondensableFlowRateCell =struct();
    fOutlet_Temp_Hot_New = fOutlet_Temp_Hot;
    acCondensateNames = '';
    fCondensateHeatFlow = 0;
    return
end
%gets the Names of all Substances present in the flows
acSubstanceNamesFlow = oFlow_Hot.oMT.csSubstances(oFlow_Hot.arPartialMass ~= 0);

%calculates the vapor pressures at the wall temperature of
%the cooled gas loop and the partial pressure of each substance. Then uses
%these values to calculate the relative humidity for each substance.
%Condensation generally occurs at the dew point which is the point where
%the relative humidity reaches 100% (or in this case 1)
mVaporPressures = zeros(length(acSubstanceNamesFlow),1);
mMolarMassSubstance = zeros(length(acSubstanceNamesFlow),1);
mPartialMass = zeros(length(acSubstanceNamesFlow),1);
mCondensableMassFlow = zeros(length(acSubstanceNamesFlow),1);

fFlowRate = abs(oFlow_Hot.fFlowRate)/iIncrements;
fPressure = oFlow_Hot.fPressure;
fMolarMassFlow = oFlow_Hot.fMolarMass;

for n = 1: length(acSubstanceNamesFlow)
    mVaporPressures(n) = oHX.oMT.calculateVaporPressure(fTwall, acSubstanceNamesFlow{n});
    
    mMolarMassSubstance(n) = oFlow_Hot.oMT.afMolarMass(oFlow_Hot.oMT.tiN2I.(acSubstanceNamesFlow{n}));
    mPartialMass(n) = oFlow_Hot.arPartialMass(oFlow_Hot.oMT.tiN2I.(acSubstanceNamesFlow{n}));
    
    mCondensableMassFlow(n) = afCondensableFlowRate(oFlow_Hot.oMT.tiN2I.(acSubstanceNamesFlow{n}));
end

%Note the factors to split the flow into boundary flow and core flow are
%used later on, here basically only the decision if something condenses at
%all is made
mMaxMassFraction = (mVaporPressures./fPressure).*(mMolarMassSubstance./fMolarMassFlow);
mMaxMassFlow = fFlowRate.*mMaxMassFraction;
%mMassFlow = fFlowRate.*mPartialMass;
    
mMaxCondensateMassFlow = mCondensableMassFlow - mMaxMassFlow;

fCoreHeatFlowTotal = 0;
%%
%checks the boundaryflow for condensation 
if max(mMaxCondensateMassFlow) > 0
    %gets the names of the subsances that are condensing
    %and their indices as well as the phase change enthalpy
    acCondensateNames = acSubstanceNamesFlow(mMaxCondensateMassFlow > 0);
    aiCondensateIndex = zeros(length(acCondensateNames),1);
    for j = 1:length(acCondensateNames)
        aiCondensateIndex(j) = oFlow_Hot.oMT.tiN2I.(acCondensateNames{j});
        sPhaseChangeEnthalpy.(acCondensateNames{j}) = oHX.mPhaseChangeEnthalpy(aiCondensateIndex(j)); %J/kg
    end

    %Now it is necessary to explain a bit about the
    %assumptions made for the condensation: First the flow
    %where condensation takes place is split into a core
    %flow and a boundary layer flow. The boundary layer is
    %assumed to have the same temperature as the wall and
    %this is also where condensation will take place most
    %of the time. However it is also possible for the core flow to get cold
    %enough for condensation to occur there. Therefore it is also necessary
    %to check the core flow for condensation. Also based on the relative
    %humidity for each flow it is possible to calculate the mass fraction
    %for each substance that would be present in the flow at 100% humidity.
    %Everything above that mass flow can condense in the heat exchanger,
    %assuming that sufficient heat flow is provided for that.
    
    mVaporPressuresCore = zeros(length(acSubstanceNamesFlow),1);
    
    for n = 1: length(acSubstanceNamesFlow)
        mVaporPressuresCore(n) = oHX.oMT.calculateVaporPressure(fOutlet_Temp_Hot, acSubstanceNamesFlow{n});
    end
    
    mMaxMassFractionCore = (mVaporPressuresCore./fPressure).*(mMolarMassSubstance./fMolarMassFlow);
    mMaxMassFlowCore = fFlowRate.*mMaxMassFractionCore;
    
    %calculates the flow rate for each substance in the boundary flow that
    %can condense, assuming that 5% of the flow are boundary flow.
    mCondenseableFlowRateBoundary = (mCondensableMassFlow*0.05)-(mMaxMassFlow*0.05);
    mCondenseableFlowRateBoundary(mCondenseableFlowRateBoundary < 0) = 0;
    
    %calculates the flow rate for each substance in the core flow that can
    %condense
    mCondenseableFlowRateCore = (mCondensableMassFlow-mCondenseableFlowRateBoundary)-(mMaxMassFlowCore);
    mCondenseableFlowRateCore(mCondenseableFlowRateCore < 0) = 0;
    
    %by adding the two values from above the overall condenseable flow rate
    %for each substance can be calculated
    mCondenseableFlowRate = mCondenseableFlowRateBoundary+ mCondenseableFlowRateCore;
    mCondenseableFlowRate = mCondenseableFlowRate(mCondenseableFlowRate ~= 0);
    
    %in order to keep track of what condenses the flowrates are saved in a
    %struct
    sCondenseableFlowRate = struct();
    
    %just used to decide how the mass flow has to be split up
    fOverallPhaseChangeEnthalpyFlow = 0;
    for k = 1:length(mCondenseableFlowRate)
       fOverallPhaseChangeEnthalpyFlow = fOverallPhaseChangeEnthalpyFlow+ mCondenseableFlowRate(k)*sPhaseChangeEnthalpy.(acCondensateNames{k});
    end
    
    for k = 1:length(mCondenseableFlowRate)
        sCondenseableFlowRate.(acCondensateNames{k}) = mCondenseableFlowRate(k);
        %it is also necessary to divide the overall heatflow into seperate
        %flows for each substance
        if fOverallPhaseChangeEnthalpyFlow == 0
            sHeatFlow.(acCondensateNames{k}) = 0;
        else
            sHeatFlow.(acCondensateNames{k}) = fHeatFlow*...
                ((sCondenseableFlowRate.(acCondensateNames{k})*sPhaseChangeEnthalpy.(acCondensateNames{k}))/fOverallPhaseChangeEnthalpyFlow);
        end
    end
    
    %now it is necessary to discern between the different species that
    %condensate
    for l = 1:length(acCondensateNames)
        %gets the maximum condensed mass flow over this 
        %increment of the heat exchanger
        fMaxCondensateFlowRate = fHeatFlow/sPhaseChangeEnthalpy.(acCondensateNames{l});
        %now if thet flow rate is larger or equal to the
        %flowrate of the condensing substance in the
        %boundary layer the temperature of the core will
        %remain the same
        if sCondenseableFlowRate.(acCondensateNames{l}) >= fMaxCondensateFlowRate
            sCoreHeatFlow.(acCondensateNames{l}) = 0;
            sCondensableFlowRateCell.(acCondensateNames{l}) = fMaxCondensateFlowRate;
            
        else
            %if that is not the case the actual condensate
            %heatflow has to be calculated
            fCondensateHeatFlow = sCondenseableFlowRate.(acCondensateNames{l})*sPhaseChangeEnthalpy.(acCondensateNames{l});
            sCoreHeatFlow.(acCondensateNames{l}) = sHeatFlow.(acCondensateNames{l}) - fCondensateHeatFlow;
            sCondensableFlowRateCell.(acCondensateNames{l}) = sCondenseableFlowRate.(acCondensateNames{l});
        end
    end
    
    %the individual heatflows that are left for the core are summed up to a
    %new total heat flow into the core
    for k = 1:length(acCondensateNames)
        fCoreHeatFlowTotal = fCoreHeatFlowTotal + sCoreHeatFlow.(acCondensateNames{k});
    end
    fOutlet_Temp_Hot_New = (-fCoreHeatFlowTotal/fHeat_Capacity_Flow_Hot)+fEntry_Temp_Hot;
    
    fCondensateHeatFlow = fHeatFlow-fCoreHeatFlowTotal;
else
    %without condensation the outlet temp remains the same
    sCondensableFlowRateCell.Condensation = 0;
    fOutlet_Temp_Hot_New = fOutlet_Temp_Hot;
    acCondensateNames = '';
    fCondensateHeatFlow =  0;
    %if there is no condensation in the boundary flow the core flow will 
    %also not condense therefore the return here
    return
end
end
