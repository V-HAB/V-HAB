classdef branch < base & event.source
    %
    %
    %
    %
    %TODO
    %   * possibility to include time step calculator, prepared ones e.g.
    %     for detection of pressure/mass oscillations in boundary nodes
    %     (i.e. pressures equalized) -> set timestep for exact equalization
    
    properties (SetAccess = private, GetAccess = private)
        chSetBranchFlowRate;
    end
    
    properties (SetAccess = private, GetAccess = protected)
        % Callback to set time step (default: inf) in [s]
        setTimeStep;
        
    end
    
    properties (SetAccess = private, GetAccess = public)
        aoBranches;
        iBranches;
        
        fLastUpdate = -10;
        
        
        % Mode:
        %   * simple: coeffs for f2fs, fan dP = f(fr, density), p2p = flow
        %     rates from last tick used
        %   * complex: f2f callbacks for dP, fan callback, p2p immediately
        %     called in every iteration for absorption rate (requires
        %     specific method in p2p)
        sMode = 'simple';
    end
    
    properties (SetAccess = private, GetAccess = protected) %, Transient = true)
        %TODO These properties should be transient. That requires a static
        % method (loadobj) to be implemented in this class, so when the
        % simulation is re-loaded from a .mat file, the properties are
        % reset to their proper values.
        bRegisteredOutdated = false;
    end
    
    properties (SetAccess = private, GetAccess = public)
        % Solving mechanism supported by the solver
        sSolverType;
        
        % Cached solving objects (from [procs].toSolver.coefficient)
        aoSolverProps;
        
        % Reference to the matter table
        % @type object
        oMT;
        
        oTimer;
        
        
        
        % Variable pressure phases by UUID
        poVariablePressurePhases;
        
        % Boundary nodes
        poBoundaryPhases;
        
        % Maps variable pressure phases / branches, using their UUIDs, to
        % the according column in the solving matrix
        piObjUuidsToColIndex;
        
        poColIndexToObj;
        
        
        %TODO These properties should be transient. That requires a static
        % method (loadobj) to be implemented in this class, so when the
        % simulation is re-loaded from a .mat file, the properties are
        % reset to their proper values.
        csVariablePressurePhases;
        csObjUuidsToColIndex;
        csBoundaryPhases;
        
        % Sum of flow coeffs for each branch
        % For volumetric flow rate!
        afPressureDropCoeffsSum;
        
        
        % Last values of caclulated flow rates.
        afFlowRates;
    end
    
    
    properties (SetAccess = protected, GetAccess = public)
        iPostTickPriority = -1;
    end
    
    
    methods
        function this = branch(aoBranches, sMode)
            %TODO check for every branch!
%             if isempty(oBranch.coExmes{1}) || isempty(oBranch.coExmes{2})
%                 this.throw('branch:constructor',['The interface branch %s is not properly connected.\n',...
%                                      'Please make sure you call connectIF() on the subsystem.'], oBranch.sName);
%             end
            
            if (nargin >= 2) && ~isempty(sMode)
                this.sMode = sMode;
            end
            
            this.sSolverType = sif(strcmp(this.sMode, 'complex'), 'callback', 'coefficient');
            
            
            this.aoBranches = aoBranches;
            this.iBranches  = length(this.aoBranches);
            this.oMT        = this.aoBranches(1).oMT;
            this.oTimer     = this.aoBranches(1).oTimer;
            
            %this.aoSolverProps = solver.matter.base.type.(this.sSolverType).empty(0, size(this.oBranch.aoFlowProcs, 2));

%             for iP = 1:length(this.oBranch.aoFlowProcs)
%                 if ~isfield(this.oBranch.aoFlowProcs(iP).toSolve, this.sSolverType)
%                     this.throw('branch:constructor', 'F2F processor ''%s'' does not support the %s solving method!', this.oBranch.aoFlowProcs(iP).sName, this.sSolverType);
%                 end
% 
%                 this.aoSolverProps(iP) = this.oBranch.aoFlowProcs(iP).toSolve.(this.sSolverType);
%             end
            
            
            this.chSetBranchFlowRate = cell(1, this.iBranches);
            
            for iB = 1:this.iBranches 
                this.chSetBranchFlowRate{iB} = this.aoBranches(iB).registerHandlerFR(this);
                
                this.aoBranches(iB).bind('outdated', @this.registerUpdate);
            end
            
            
            this.setTimeStep = this.oTimer.bind(@(~) this.registerUpdate(), inf);
            
            
            this.initialize();
        end
        
    end
    
    
    methods (Access = protected)
        function initialize(this)
            % Initialized variable pressure phases / branches
            
            this.poVariablePressurePhases = containers.Map();
            this.piObjUuidsToColIndex     = containers.Map();
            this.poBoundaryPhases         = containers.Map();
            this.poColIndexToObj          = containers.Map('KeyType', 'uint32', 'ValueType', 'any');
            
            iColIndex = 0;
            
            for iB = 1:this.iBranches
                for iP = 1:2
                    oP = this.aoBranches(iB).coExmes{iP}.oPhase;
                    
                    % Variable pressure phase - add to reference map if not
                    % present yet, generate index for matrix column
                    if isa(oP, 'matter.phases.gas_pressure_manual')
                        if ~this.poVariablePressurePhases.isKey(oP.sUUID)

                            this.poVariablePressurePhases(oP.sUUID) = oP;

                            iColIndex = iColIndex + 1;

                            this.piObjUuidsToColIndex(oP.sUUID) = iColIndex;
                            this.poColIndexToObj(iColIndex)     = oP;
                        end
                    
                    % 'Real' phase - boundary condition
                    else
                        if ~this.poBoundaryPhases.isKey(oP.sUUID)
                            this.poBoundaryPhases(oP.sUUID) = oP;
                        end
                    end
                end
                
                
                iColIndex = iColIndex + 1;
                oB = this.aoBranches(iB);
                
                this.piObjUuidsToColIndex(oB.sUUID) = iColIndex;
                this.poColIndexToObj(iColIndex)     = oB;
                
                % Init
                this.chSetBranchFlowRate{iB}(0, []);
            end
            
            
            this.csVariablePressurePhases = this.poVariablePressurePhases.keys();
            this.csObjUuidsToColIndex     = this.piObjUuidsToColIndex.keys();
            this.csBoundaryPhases         = this.poBoundaryPhases.keys();
        end
        
        
        function [ aafPhasePressuresAndFlowRates, afBoundaryConditions ] = generateMatrices(this)
            % afBoundaryConditions is the B vector mostly with the boundary
            % node pressures (later also fan pressure deltas)
            
            % Average density
            afDensities = nan(1, length(this.csBoundaryPhases));
            
            for iP = 1:length(this.csBoundaryPhases)
                afDensities(iP) = this.poBoundaryPhases(this.csBoundaryPhases{iP}).fDensity;
            end
            
            fDensity = mean(afDensities);
            
            
            this.afPressureDropCoeffsSum = nan(1, this.iBranches);
            
            % One equation per branch, one per variable pressure phase
            iVariablePressurePhases = length(this.csVariablePressurePhases);
            iMatrixHeight           = this.iBranches + iVariablePressurePhases;
            
            aafPhasePressuresAndFlowRates = zeros(iMatrixHeight, iVariablePressurePhases + this.iBranches);
            afBoundaryConditions          = zeros(iMatrixHeight, 1);
            
            
            iRow = 0;
            
            % Loop branches, generate equation row to calculate flow rate
            % DP = C * FR, or P_Left - P_Right = C * FR
            for iB = 1:this.iBranches
                iRow = iRow + 1;
                oB   = this.aoBranches(iB);
                
                
                
                %TODO in case of complex solver, this.afPressDropCoeffSums
                %     is relative to mass flow rate, in other case relative
                %     to volumetric flow rate. Stupid.
                if strcmp(this.sMode, 'complex')
                    % dP = Coeff * FR.
                    
                    % If flow rate is zero, use minTs as initial flow rate.
                    % Depending on pressure difference of this branch, set
                    % positive or negative - as we do not have active
                    % components, the pressure difference determines the
                    % flow direction! Yay!
                    fFlowRate = this.afFlowRates(iB);
                    
                    %TODO round somewhere? In between iterations?
                    if fFlowRate == 0
                        fFlowRate = this.oTimer.fMinimumTimeStep;
                        
                        % Negative pressure difference? Negative guess!
                        if oB.coExmes{1}.getPortProperties() < oB.coExmes{2}.getPortProperties()
                            fFlowRate = -1 * fFlowRate;
                        end
                    end
                    
                    
                    afPressureDrops = nan(1, oB.iFlowProcs);

                    for iProc = 1:oB.iFlowProcs
                        afPressureDrops(iProc) = oB.aoFlowProcs(iProc).toSolve.(this.sSolverType).calculateDeltas(fFlowRate);
                    end

                    % Got the absolute pressure drops, so now we need to 
                    % divide that with the flow rate to get the coeff!
                    this.afPressureDropCoeffsSum(iB) = sum(afPressureDrops) / abs(fFlowRate);
                    fCoeffFlowRate = this.afPressureDropCoeffsSum(iB);
                    
                else
                    afPressureDropCoeffs = nan(1, oB.iFlowProcs);
                    
                    
                    %TODO might change after calculation, because pressure
                    %     of VPP might be adapted. At least one iteration
                    %     even for the simple case?
                    %     Cause e.g. checkvalve ... might be some flow for
                    %     one step, which might be up to 20 secs ...
                    bFlowRatePositive = oB.coExmes{1}.getPortProperties() >= oB.coExmes{2}.getPortProperties();
                    

                    for iProc = 1:oB.iFlowProcs
                        afPressureDropCoeffs(iProc) = oB.aoFlowProcs(iProc).toSolve.(this.sSolverType).getCoefficient(bFlowRatePositive);
                    end
                    
                    this.afPressureDropCoeffsSum(iB) = sum(afPressureDropCoeffs);

                    % For the matrix coeffs, we do need to convert the coeff,
                    % which is relative to the VOLUMETRIC flow rate, to the
                    % absolute flow rate - incompresible, use mean density of
                    % all boundary nodes!
                    fCoeffFlowRate = this.afPressureDropCoeffsSum(iB) / fDensity;
                end
                
                
                % Set flow coeff
                iCol = this.piObjUuidsToColIndex(oB.sUUID);
                
                aafPhasePressuresAndFlowRates(iRow, iCol) = -1 * fCoeffFlowRate;
                
                
                % Equation depending on pressure left/right
                %   P-T, T-P, T-T, P-P
                % If left side of branch - positive value on matrix,
                % negative on vector. Vice versa for right side.
                iSign = 1;
                
                for iP = 1:2
                    oE = oB.coExmes{iP};
                    oP = oB.coExmes{iP}.oPhase;
                    
                    if this.poBoundaryPhases.isKey(oP.sUUID)
                        % NEGATIVE - right side! For second iteration, sign
                        % would be negative - i.e. value added!
                        % If both are boundary conditions, that means
                        % 0 - P_left + P_right = P_right - P_left
                        % This is ok, as the flow coeff above is also added
                        % with a negative sign, i.e.:
                        % -C * FR = P_right - P_left     | *-1
                        % C * FR  = - P_right + P_left
                        afBoundaryConditions(iRow) = afBoundaryConditions(iRow) ...
                                                    - iSign * oE.getPortProperties(); %oP.fPressure;
                        
                    else
                        iCol = this.piObjUuidsToColIndex(oP.sUUID);
                        
                        aafPhasePressuresAndFlowRates(iRow, iCol) = iSign;
                    end
                    
                    
                    % Multiplication not really necessary, only two loops
                    iSign = -1 * iSign;
                end
            end
            
            
            
            % Loop variable pressure phases, generate eq row to enforce sum
            % of flow rates is zero (or the BC/p2p conds)
            for iP = 1:iVariablePressurePhases
                iRow   = iRow + 1;
                oP     = this.poVariablePressurePhases(this.csVariablePressurePhases{iP});
                fFrSum = 0;
                iAdded = 0;
                
                % the equation has to be removed if iAdded is < 2. If for
                % example:
                %    p2p + solved branch -> ok
                %    unsolved branch + solved branch -> ok
                %    solved + solved branch -> ok
                %    if e.g. just p2p or unsolved branch - don't add!
                
                
                % Check for p2p and branches NOT solved by this solver!
                %TODO right now, works only for one p2p. Loop p2ps and sum
                %     up the filter ratios
                %   ALSO: assuming this oP phase is the 'in' phase. Not
                %   necessarily the case! Check oP == oP2p.oIn!
                %TODO also: just adsorption, doesn't work for p2p that
                %     dumps mass into the VPP
                arRatiosFiltered = zeros(1, oP.iProcsEXME);
                
%                 aoE = [ oP.coProcsEXME{:} ]; aoF = [ aoE.oFlow ]; aoB = [ aoF.oBranch ];
%                 disp(oP.oStore.sName);
%                 
%                 for iF = 1:length(aoF)
%                     find(aoF(iF).arPartialMass)
%                     this.oMT.csSubstances(find(aoF(iF).arPartialMass))
%                 end
                
                if oP.iProcsP2Pflow > 0
%                     if this.oTimer.fTime >= 39
%                         disp('39s');
%                     end
                    
                    arRatiosFiltered = oP.coProcsP2Pflow{1}.calculateFilterRates();
                    
%                     if this.oTimer.fTime >= 39
%                         fprintf('[%i|%fs] %s-%s\n', this.oTimer.iTick, this.oTimer.fTime, oP.oStore.sName, oP.sName);
%                         disp(arRatiosFiltered);
%                     end
                end
                
                
                % Connected branches - col indices in matrix
                for iB = 1:oP.iProcsEXME
                    % P2ps definitely not sovled by this solver.
                    if isa(oP.coProcsEXME{iB}.oFlow, 'matter.procs.p2p')
                        continue;
                    end

                    
                    oB = oP.coProcsEXME{iB}.oFlow.oBranch;
                    
                    % Ok now check - if this phase is on exme 1, i.e. the
                    % left side - positive flow rate means OUTWARDS. If on
                    % the right side, positive means INWARDS.
                    % Therefore if on exme 1, and positive, value must be
                    % negative, i.e. sign -1
                    iSign = 1;
                    
                    if oB.coExmes{1}.oPhase == oP
                        iSign = -1;
                    end
                    
                    
                    % Not solved by us? Use as boundary cond flow rate!
                    if ~this.piObjUuidsToColIndex.isKey(oB.sUUID)
                        fFrSum = fFrSum - iSign * oB.fFlowRate;
                    else
                        iCol = this.piObjUuidsToColIndex(oB.sUUID);
                        
                        
                        % Check coeff of branch - if inf, don't add this
                        % term! No flow!
                        if isnan(this.afPressureDropCoeffsSum(this.aoBranches(iB) == oB))
                            continue;
                        end
                        
                        
                        aafPhasePressuresAndFlowRates(iRow, iCol) = iSign;
                        iAdded = iAdded + 1;
                        
                        
                        
                        % Do we have a p2p filter rate for this inflow?
                        if arRatiosFiltered(iB) > 0
                            bPosPressDiff = oB.coExmes{1}.getPortProperties() > oB.coExmes{2}.getPortProperties();
                            bNegPressDiff = oB.coExmes{1}.getPortProperties() < oB.coExmes{2}.getPortProperties();
                            
                            %TODO for initial, no pressure differences etc
                            %     available ... right now, iteration done
                            %     twice to ensure correct results.
                            bInflow = ...
                                (bPosPressDiff && (iSign == 1)) || ...
                                (bNegPressDiff && (iSign == -1));
                            
                            
%                             if this.oTimer.fTime >= 60
%                                 fprintf('Branch %i: %i inflow? (%f)\n', iB, bInflow, arRatiosFiltered(iB));
%                             end
                            
                            
                            if bInflow
                                % Ok, so part of the inflowing rates are
                                % filtered, for example normally:
                                % FR_1 + FR_2  + FR_3 = 0
                                % (assuming phase ins on 'right' side of
                                % all branches)
                                % With a p2 adsorption (assuming 1/3 are
                                % positive values, i.e. inflows):
                                % FR_1 + FR_2 + FR_3 = 0.3*FR_1 + 0.1*FR_3
                                %
                                % Therefore: iSign * (100% - filter rate);
                                aafPhasePressuresAndFlowRates(iRow, iCol) = iSign * (1 - arRatiosFiltered(iB));
                                
                                iAdded = iAdded + 1;
                            end
                        
                            
                        else
%                             if this.oTimer.fTime >= 60
%                                 fprintf('Branch %i: p2p partial NOT gt 0: %f\n', iB, arRatiosFiltered(iB));
%                             end
                        end
                        
                    end
                end
                
                
                % If unsolved branch as BC, one solved branch is
                % sufficient.
                % If no branch added, don't add bc flow rate.
                if fFrSum ~= 0 && iAdded >= 1
                    afBoundaryConditions(iRow) = fFrSum;
                end
                % Remove everything 
%                 elseif iAdded < 2 && fFrSum == 0
%                     for iC = 1:size(aafPhasePressuresAndFlowRates, 2)
%                         aafPhasePressuresAndFlowRates(iRow, iC) = 0;
%                     end
                

                %fprintf('[%i|%fs] %s-%s \t\t jou - diff last update: %.12f\n', this.oTimer.iTick, this.oTimer.fTime, oP.oStore.sName, oP.sName, (this.oTimer.fTime - oP.fLastMassUpdate) == 0);

%                 if fFrSum == 0
%                     % Check mass in VPP - if > then original mass, set flow
%                     % rate sum to -1*minTS/100 --> should slowly decrease
%                     fDiff = tools.round.prec(oP.fInitialMass - oP.fMass, this.oTimer.iPrecision);
%                     
%                     if fDiff > 0 %oP.fInitialMass > oP.fMass
%                         fFrSum = +1 * this.oTimer.fMinimumTimeStep / 10;%/ 100;
%                         
% %                         fprintf('[%fs] %s-%s \t\t Initial > MASS, sum: %.12f \t\t INOUT: %.24f\n', this.oTimer.fTime, oP.oStore.sName, oP.sName, fFrSum, oP.fCurrentTotalMassInOut);
%                         
%                     elseif fDiff < 0  %oP.fInitialMass < oP.fMass
%                         fFrSum = -1 * this.oTimer.fMinimumTimeStep / 10;%/ 100;
%                         
% %                         fprintf('[%fs] %s-%s \t\t Initial < MASS, sum: %.12f \t\t INOUT: %.24f\n', this.oTimer.fTime, oP.oStore.sName, oP.sName, fFrSum, oP.fCurrentTotalMassInOut);
%                         
%                     else
%                         %fprintf('[%fs] %s-%s \t\t Initial == MASS\n', this.oTimer.fTime, oP.oStore.sName, oP.sName);
%                     end
%                     
%                     
%                     afBoundaryConditions(iRow) = fFrSum;
%                 end
            end
        end
        
        
        function registerUpdate(this, ~)
            if this.bRegisteredOutdated
                return;
            end
            
            this.bRegisteredOutdated = true;
            
            for iB = 1:this.iBranches
                for iE = sif(this.aoBranches(iB).fFlowRate >= 0, 1:2, 2:-1:1)
                    this.aoBranches(iB).coExmes{iE}.oPhase.massupdate();
                end
            end
            
            this.oTimer.bindPostTick(@this.update, this.iPostTickPriority);
        end
        
        
        function update(this)
%             disp(this.oTimer.fTime);
%             disp(this.oTimer.fTime - this.fLastUpdate);
            
            this.fLastUpdate         = this.oTimer.fTime;
            this.bRegisteredOutdated = false;
            
            
            for iB = 1:this.iBranches
                this.afFlowRates(iB) = this.aoBranches(iB).fFlowRate;
            end
            
            
            %TOOD
            % Now iterate ... in case of complex solver ...
            % Only really set the resulting pressures/flow rates if
            % converged.
            % FRs - afFlowRates used in iterations, works (for calcDeltas)
            % VPP (var. press. phases) don't need to be updated, densities
            %     etc from last tick used anyways. Well, for initial flow
            %     rate (if FR was zero), maybe the current value from the
            %     iteration then needed?
            
            
            rError    = inf;
            afResults = [];
            
            % Only iterate for the complex solving mechanism
            %rErrorMax = 0.01;
            rErrorMax = sif(strcmp(this.sMode, 'complex'), 0.01, inf);
            
            % The initial flow rates are all zero, so initial rError below
            % will be inf -> that's good, e.g. the p2ps need a correct set
            % of flow rate directions to be included in equations!
            while abs(rError) >= rErrorMax
                afPrevFrs = this.afFlowRates;
                
                % Regenerates matrices, gets coeffs from flow procs
                [ aafPhasePressuresAndFlowRates, afBoundaryConditions ] = this.generateMatrices();
                
                
                %aafPhasePressuresAndFlowRates = tools.round.prec(aafPhasePressuresAndFlowRates, this.oTimer.iPrecision);
                %afBoundaryConditions          = tools.round.prec(afBoundaryConditions,          this.oTimer.iPrecision);

                % Solve
                %hT = tic();
                afResults = aafPhasePressuresAndFlowRates \ afBoundaryConditions;
                %toc(hT);

                %disp(afResults);
                %keyboard();
                
                
                % Round everything to the precision, else we get small
                % errors
                %afResults = tools.round.prec(afResults, this.oTimer.iPrecision);
                

                for iR = 1:length(this.csObjUuidsToColIndex)
                    oObj = this.poColIndexToObj(iR);

                    if isa(oObj, 'matter.branch')
                        iB = find(this.aoBranches == oObj, 1);
                        this.afFlowRates(iB) = afResults(iR);
                    end
                end
                
                
                
                %this.afFlowRates = tools.round.prec(this.afFlowRates, this.oTimer.iPrecision);
                
                rError = max(abs(this.afFlowRates ./ afPrevFrs) - 1);
            end
            
            
            %TODO done iterating if converged!
            
            
            % Ok now go through results - variable pressure phase pressures
            % and branch flow rates - and set!
            for iR = 1:length(this.csObjUuidsToColIndex)
                oObj = this.poColIndexToObj(iR);
                
                if isa(oObj, 'matter.phases.gas_pressure_manual')
                    oObj.setPressure(afResults(iR));
                    
                    
                elseif isa(oObj, 'matter.branch')
                    iB = find(this.aoBranches == oObj, 1);
                    
                    %this.chSetBranchFlowRate{iB}(afResults(iR), []);
                    this.chSetBranchFlowRate{iB}(this.afFlowRates(iB), []);
                end
            end
            
            
            % Don't need the actual pressures right now, but 
            % can easily calculated them using the coeffs!
            %
            
            
            %TODO check total flow rates for each phase, vs. total flow
            %     rates for all connected phases -> calculate time required
            %     for the phases to equalize in mass --> max TS
        end
    end
end
