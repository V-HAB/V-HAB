classdef controller < base
    
    properties (SetAccess = public, GetAccess = public)
        
    end
    
    properties (SetAccess = protected, GetAccess = public)
        aoBranches;
        
        aoSolvers;
        
        bRegisteredOutdated = false;
    end
    
    methods
        
        %% Constructor
        function this = controller(aoBranches)
            this.aoBranches = aoBranches;
            this.aoSolvers  = [ this.aoBranches.oHandler ];
            
            for iB = 1:length(this.aoBranches)
                this.aoBranches(iB).bind('outdated', @this.registerUpdate);
            end
        end
        
        
    end
    
    methods (Access = protected)
        function registerUpdate(this, ~)
            if this.bRegisteredOutdated, return; end;
            
            this.aoBranches(1).oTimer.bindPostTick(@this.update, -3);
            this.bRegisteredOutdated = true;
        end
        
        
        function update(this, ~)
            this.bRegisteredOutdated = false;
            % TO DO: why create so many console outputs?
            % fprintf('[%i] CONTROLLER\n', this.aoBranches(1).oTimer.iTick);
            
            afTotalCoeffs = [ this.aoSolvers.fTotalCoeff ];
            
            if isempty(afTotalCoeffs) || length(afTotalCoeffs) < length(this.aoSolvers)
                %%%disp('CTR RETURN');
                
                return;
            end
            
            %keyboard();
            
            % Phases with dynamic pressure
            aoPhasesDynPressure   = matter.phases.gas_pressure_manual.empty(0);
            
            for iB = 1:length(this.aoBranches)
                for iE = 1:2
                    if isa(this.aoBranches(iB).coExmes{iE}.oPhase, 'matter.phases.gas_pressure_manual')
                        oP = this.aoBranches(iB).coExmes{iE}.oPhase;
                        
                        if ~any(aoPhasesDynPressure == oP)
                            aoPhasesDynPressure(end + 1) = oP;
                        end
                    end
                end
            end
            
            
            % Func handle to calc pressure, connected branches - coeff, 
            % pressures on other side, branches with _manual on other side
            cPressureCalc = cell(length(aoPhasesDynPressure), 4);
            
            for iP = 1:length(aoPhasesDynPressure)
                oP = aoPhasesDynPressure(iP);
                % Check other phases
                % If _manual -> add to cPressureCalc{iP, 2} = [ 2 5 4 ];
                
                
                afCoeffs    = nan(1, oP.iProcsEXME);
                afPressures = nan(1, oP.iProcsEXME);
                aiManual    = nan(1, oP.iProcsEXME);
                
                
                % Get branches of phase
                for iE = 1:oP.iProcsEXME
                    oExme        = oP.coProcsEXME{iE};
                    iOtherPhase  = sif(oExme.oFlow.oBranch.coExmes{1} == oP, 2, 1);
                    oOtherPhase  = oExme.oFlow.oBranch.coExmes{iOtherPhase}.oPhase;
                    afCoeffs(iE) = oExme.oFlow.oBranch.oHandler.fTotalCoeff;
                    
                    if isa(oOtherPhase, 'matter.phases.gas_pressure_manual')
                        %aiManual(end + 1) = find(aoPhasesDynPressure == oOtherPhase, 'first');
                        aiManual(iE) = find(aoPhasesDynPressure == oOtherPhase, 'first');
                        
                        afPressures(iE) = nan;
                        
                    else
                        afPressures(iE) = oOtherPhase.fMassToPressure * oOtherPhase.fPressure;
                    end
                end
                
                
                fCoeffsSum = sum(afCoeffs);
                csEquation = cell(1, oP.iProcsEXME);
                
                for iE = 1:oP.iProcsEXME
                    if isnan(afPressures(iE))
                        csEquation{iE} = sprintf('(afCoeffs(%i) / fCoeffsSum * afPressuresNew(%i))', iE, aiManual(iE));
                    else
                        csEquation{iE} = sprintf('(afCoeffs(%i) / fCoeffsSum * afPressures(%i))', iE, iE);
                    end
                end
                
                sEquation = '@(afPressuresNew) 0';
                
                for iS = 1:length(csEquation)
                    sEquation = [ sEquation '+' csEquation{iS} ];
                end
                
                sEquation = [ sEquation ';' ];
                
                cPressureCalc{iP, 1} = eval(sEquation);
                cPressureCalc{iP, 2} = afCoeffs;
                cPressureCalc{iP, 3} = afPressures;
                cPressureCalc{iP, 4} = aiManual;
            end
            
            
            
            % Now go through cPressureCalc and execute the ones with the
            % least params on {4}
            afPressuresNew = nan(length(aoPhasesDynPressure), 1);
            iIteration = 0;
            
            while any(isnan(afPressuresNew))
                iIteration = iIteration + 1;
                
                for iP = 1:size(cPressureCalc, 1)
                    aiManuals = cPressureCalc{iP, 4};
                    bSomeNan  = false;
                    
                    for iM = 1:length(aiManuals)
                        if ~isnan(aiManuals(iM)) && isnan(afPressuresNew(aiManuals(iM)))
                            bSomeNan = true;
                        end
                    end
                    
                    if ~bSomeNan
                        
                        afPressuresNew(iP) = cPressureCalc{iP, 1}(afPressuresNew);
                        
                        % fprintf('CALC PRESSURE %i --> %f  --> org: %f\n', iP, afPressuresNew(iP), aoPhasesDynPressure(iP).fPressure);
                    end
                end
                
                
                if iIteration > 10
                    keyboard();
                end
            end
            
            
            
            for iP = 1:size(cPressureCalc, 1)
                %aoPhasesDynPressure(iP).setPressure(afPressuresNew(iP));
            end
        end
    end
end
