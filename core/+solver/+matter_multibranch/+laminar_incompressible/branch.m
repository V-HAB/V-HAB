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
        sMode = 'complex';
        
        
        
        iLastWarn = -1000;
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
        
        % Temporary - active flow f2f procs - pressure rise (or drop)
        afTmpPressureRise;
    end
    
    
    properties (SetAccess = protected, GetAccess = public)
        iPostTickPriority = -1;
        iPostTickPriorityReUpdate = 2;
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
            
            % Preset
            this.afTmpPressureRise = zeros(1, this.iBranches);
            
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
            %fDensity = 1.225;
            
            this.out(1, 3, 'props', 'Mean density: %f', { fDensity });
            
            
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
                
                
                % If we have a branch with one, active component -->
                % special treatment (no coefficient - get pressure rise
                % based on previous iteration flow rate - add total value
                % as boundary condition (so iteration checks convergence)
                bActiveBranch = false;
                
                if (oB.iFlowProcs == 1) && isa(oB.aoFlowProcs(1), 'components.fan')
                    
                    for iP = 1:2
                        if this.poBoundaryPhases.isKey(oB.coExmes{iP}.oPhase.sUUID)
                            this.throw('generateMatrices', 'Active f2f proc (fan component) - both sides need to be variable pressure phases!');
                        end
                    end
                    
                    bActiveBranch = true;
                end
                
                
                if bActiveBranch
                    fCoeffFlowRate = 0;
                    
                %TODO in case of complex solver, this.afPressDropCoeffSums
                %     is relative to mass flow rate, in other case relative
                %     to volumetric flow rate. Stupid.
                elseif strcmp(this.sMode, 'complex')
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
                
                this.out(1, 3, 'props', 'Branch %s: Flow Coeff %f', { oB.sName, fCoeffFlowRate});
                
                
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
                        
                        
                        
                        this.out(1, 3, 'props', 'Phase %s-%s: Pressure %f', { oP.oStore.sName, oP.sName, oE.getPortProperties() });
                        
                    else
                        iCol = this.piObjUuidsToColIndex(oP.sUUID);
                        
                        aafPhasePressuresAndFlowRates(iRow, iCol) = iSign;
                    end
                    
                    
                    % Multiplication not really necessary, only two loops
                    iSign = -1 * iSign;
                end
                
                
                % Active component? Get pressure rise based on last
                % iteration flow rate - add to boundary condition!
                if bActiveBranch
                    fFlowRate   = this.afFlowRates(iB);
                    oProcSolver = oB.aoFlowProcs(1).toSolve.(this.sSolverType);
                    
                    % calDeltas returns POSITIVE value for pressure DROP!
                    fPressureRise = -1 * oProcSolver.calculateDeltas(fFlowRate);
                    
                    % No flow, most likely?
                    if fPressureRise == 0
                        this.afTmpPressureRise(iB) = 0;
                        
                    % DROP!
                    elseif fPressureRise < 0
                        this.afTmpPressureRise(iB) = 0;
                        
                    else
                        fPressureRise = (this.afTmpPressureRise(iB) * 33 + fPressureRise) / 34;
                        
                        this.afTmpPressureRise(iB) = fPressureRise;
                    end
                    
                    % Boundary condition must be zero, can't have active
                    % component if one side is a fixed, BC phase.
                    afBoundaryConditions(iRow) = -1 * fPressureRise;
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
% % %           ~~~~~~~~~~~~~~ INACTIVE P2P COEFF VERSION ~~~~~~~~~~~~~~~~~
% % %                 arRatiosFiltered = zeros(1, oP.iProcsEXME);
% % %                 
% % % %                 aoE = [ oP.coProcsEXME{:} ]; aoF = [ aoE.oFlow ]; aoB = [ aoF.oBranch ];
% % % %                 disp(oP.oStore.sName);
% % % %                 
% % % %                 for iF = 1:length(aoF)
% % % %                     find(aoF(iF).arPartialMass)
% % % %                     this.oMT.csSubstances(find(aoF(iF).arPartialMass))
% % % %                 end
% % %                 
% % %                 if oP.iProcsP2Pflow > 0
% % % %                     if this.oTimer.fTime >= 39
% % % %                         disp('39s');
% % % %                     end
% % %                     
% % %                     arRatiosFiltered = oP.coProcsP2Pflow{1}.calculateFilterRates();
% % %                     
% % % %                     if this.oTimer.fTime >= 39
% % % %                         fprintf('[%i|%fs] %s-%s\n', this.oTimer.iTick, this.oTimer.fTime, oP.oStore.sName, oP.sName);
% % % %                         disp(arRatiosFiltered);
% % % %                     end
% % %                 end
                
                
                
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
                        
                        
% % %           ~~~~~~~~~~~~~~ INACTIVE P2P COEFF VERSION ~~~~~~~~~~~~~~~~~
% % %                         % Do we have a p2p filter rate for this inflow?
% % %                         if arRatiosFiltered(iB) > 0
% % %                             bPosPressDiff = oB.coExmes{1}.getPortProperties() > oB.coExmes{2}.getPortProperties();
% % %                             bNegPressDiff = oB.coExmes{1}.getPortProperties() < oB.coExmes{2}.getPortProperties();
% % %                             
% % %                             %TODO for initial, no pressure differences etc
% % %                             %     available ... right now, iteration done
% % %                             %     twice to ensure correct results.
% % %                             bInflow = ...
% % %                                 (bPosPressDiff && (iSign == 1)) || ...
% % %                                 (bNegPressDiff && (iSign == -1));
% % %                             
% % %                             
% % % %                             if this.oTimer.fTime >= 60
% % % %                                 fprintf('Branch %i: %i inflow? (%f)\n', iB, bInflow, arRatiosFiltered(iB));
% % % %                             end
% % %                             
% % %                             
% % %                             if bInflow
% % %                                 % Ok, so part of the inflowing rates are
% % %                                 % filtered, for example normally:
% % %                                 % FR_1 + FR_2  + FR_3 = 0
% % %                                 % (assuming phase ins on 'right' side of
% % %                                 % all branches)
% % %                                 % With a p2 adsorption (assuming 1/3 are
% % %                                 % positive values, i.e. inflows):
% % %                                 % FR_1 + FR_2 + FR_3 = 0.3*FR_1 + 0.1*FR_3
% % %                                 %
% % %                                 % Therefore: iSign * (100% - filter rate);
% % %                                 aafPhasePressuresAndFlowRates(iRow, iCol) = iSign * (1 - arRatiosFiltered(iB));
% % %                                 
% % %                                 iAdded = iAdded + 1;
% % %                             end
% % %                         
% % %                             
% % %                         else
% % % %                             if this.oTimer.fTime >= 60
% % % %                                 fprintf('Branch %i: p2p partial NOT gt 0: %f\n', iB, arRatiosFiltered(iB));
% % % %                             end
% % %                         end
                        
                    end
                end
                
                
                if oP.iProcsP2Pflow > 0
                    % No go through all p2ps, get their flow rates based on the
                    % flow rates from the previous iteration (or time step).

                    % Generate flow rates array!
                    afInFlowRates = zeros(0);
                    aarInPartials = zeros(0, this.oMT.iSubstances);

                    %keyboard();
                    for iB = 1:oP.iProcsEXME
                        oProcExme = oP.coProcsEXME{iB};
                        oBranch   = oProcExme.oFlow.oBranch;

                        if isa(oProcExme.oFlow, 'matter.procs.p2p')
                            continue;
                        end


                        % Manual
                        if ~this.piObjUuidsToColIndex.isKey(oBranch.sUUID)
                            [ fFlowRate, arFlowPartials, ~ ] = oProcExme.getFlowData();

                        % Dynamically solved branch - get CURRENT flow rate
                        % (last iteration), not last time step flow rate!!
                        else

                            % Find branch index
                            iBranchIdx = find(this.aoBranches == oBranch, 1);

                            fFlowRate = oProcExme.iSign * this.afFlowRates(iBranchIdx);


                            %[ ~, arFlowPartials, ~ ] = oProcExme.getFlowData(fFlowRate);
                            arFlowPartials = oProcExme.oFlow.arPartialMass;
                        end

                        % Only for INflows
                        if fFlowRate > 0
                            afInFlowRates(end + 1, 1) = fFlowRate;
                            aarInPartials(end + 1, :) = arFlowPartials;
                        end





                        % Get flow rate for this branch from this.afFlowRates
                        % If manual solver, get from oBranch!
                        %
                        % Check sign (oP == coExmes{1}.oPhase?)
                        % use flow rate AND partials! Partials by calling
                        % getFlowData, but then setting the own flow rate
                    end

                    for iProcP2p = 1:oP.iProcsP2Pflow
                        oProcP2p = oP.coProcsP2Pflow{iProcP2p};

                        if oProcP2p.oIn.oPhase ~= oP
                            continue;
                        end


                        [ fFlowRateP2p, ~ ] = oProcP2p.calculateFilterRate(afInFlowRates, aarInPartials);

                        % We only care about p2ps whose IN phase is the current
                        % variable presusre phase here. So therefore, a
                        % positive flow rate means an OUTflow!
                        fFrSum = fFrSum + fFlowRateP2p;

                        %disp('multi branch: TODO make sure that in the SAME tick, the according p2p / phases are updated so the new p2p flow rate, based on the new multi branch solver flow rates, are used! And that they are equal! Really equal!');
                    end
                end
                
                
                
                % If unsolved branch as BC, one solved branch is
                % sufficient.
                % If no branch added, don't add bc flow rate. This is a VPP
                % so that would only be valid if the inflow is zero! And
                % that does not really make sense.
                %TODO throw an error if fFrSum ~= 0 and iAdded == 0?
                if fFrSum ~= 0
                    if iAdded >= 1
                        afBoundaryConditions(iRow) = fFrSum;
                    else
                        this.throw('generateMatrices', 'BC flows (manual solver or p2p) but no variable, solved branches connected!');
                    end
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
            
            this.out(1, 1, 'reg-post-tick', 'Multi-Solver - register outdated? [%i]', { ~this.bRegisteredOutdated });
            
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
            this.oTimer.bindPostTick(@this.reUpdate, this.iPostTickPriorityReUpdate);
        end
        
        
        function update(this)
%             disp(this.oTimer.fTime);
%             disp(this.oTimer.fTime - this.fLastUpdate);
            
            this.fLastUpdate         = this.oTimer.fTime;
            this.bRegisteredOutdated = false;
            
            
            this.out(1, 1, 'update', 'Update multi flow rate solver');
            this.out(1, 2, 'update', 'B %s\t', { this.aoBranches.sName });
            
            
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
            %rErrorMax = sif(strcmp(this.sMode, 'complex'), 0.001, inf);
            rErrorMax  = sif(strcmp(this.sMode, 'complex'), 0.001, 0);
            %rErrorMax  = sif(strcmp(this.sMode, 'complex'), 0.1 ^ this.oTimer.iPrecision, 0);
            iIteration = 0;
            
            afBoundaryConditions = [];
            
            % The initial flow rates are all zero, so initial rError below
            % will be inf -> that's good, e.g. the p2ps need a correct set
            % of flow rate directions to be included in equations!
            while abs(rError) > rErrorMax %|| iIteration < 5
                afPrevFrs  = this.afFlowRates;
                iIteration = iIteration + 1;
                
                afPrevBoundaryConditions = afBoundaryConditions;
                
                % Regenerates matrices, gets coeffs from flow procs
                [ aafPhasePressuresAndFlowRates, afBoundaryConditions ] = this.generateMatrices();
                
                
                %aafPhasePressuresAndFlowRates = tools.round.prec(aafPhasePressuresAndFlowRates, this.oTimer.iPrecision);
                %afBoundaryConditions          = tools.round.prec(afBoundaryConditions,          this.oTimer.iPrecision);

                % Solve
                %hT = tic();
                warning('off','all');
                
                afResults = aafPhasePressuresAndFlowRates \ afBoundaryConditions;
                sLastWarn = lastwarn;
                
                warning('on','all');
                
                if ~isempty(sLastWarn) && ~isempty(strfind(sLastWarn, 'badly scaled'))
                    if (this.oTimer.iTick - this.iLastWarn) >= 100
                        warning(sLastWarn);
                        
                        this.iLastWarn = this.oTimer.iTick;
                    end
                end
                
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
                        
                        if iIteration == 1 || ~strcmp(this.sMode, 'complex')
                            this.afFlowRates(iB) = afResults(iR);
                        else
                            this.afFlowRates(iB) = (this.afFlowRates(iB) * 3 + afResults(iR)) / 4;
                        end
                    end
                end
                
                
                
                %this.afFlowRates = tools.round.prec(this.afFlowRates, this.oTimer.iPrecision);
                
                iPrecision = this.oTimer.iPrecision;
                afFrsDiff  = tools.round.prec(abs(this.afFlowRates - afPrevFrs), iPrecision);
                
                %rError = max(abs(this.afFlowRates ./ afPrevFrs) - 1);
                rError = max(afFrsDiff ./ afPrevFrs);
                %rError = tools.round.prec(max(afFrsDiff ./ afPrevFrs), iPrecision);
                
                
                % Boundary conditions (= p2p and others) changing? Continue
                % iteration!
                % Also enforces at least two iterations ... ok? BS?
                afBcChange = [ 0 ];
                
                if ~isempty(afPrevBoundaryConditions)
                    %afBcChange = tools.round.prec(afPrevBoundaryConditions - afBoundaryConditions, iPrecision);
                    afBcChange = tools.round.prec(afPrevBoundaryConditions - afBoundaryConditions, 4);
                end
                
                if isempty(afPrevBoundaryConditions) || ~all(afBcChange == 0) % ~all(afPrevBoundaryConditions == afBoundaryConditions)
                    this.out(1, 2, 'changing-boundary-conditions', 'Boundary conditions changing (p2p!), iteration %i', { iIteration });
                    rError = inf;
                end
                
                
                this.out(1, 2, 'solve-flow-rates', 'Iteration: %i with error %.12f', { iIteration, rError });
                
                if iIteration > 200
                    %keyboard();
                    this.throw('update', 'too many iterations, error %.12f', rError);
                end
            end
            
            this.out(1, 1, 'solve-flow-rates', 'Iterations: %i', { iIteration });
            
            for iR = 1:length(this.csObjUuidsToColIndex)
                oObj = this.poColIndexToObj(iR);

                if isa(oObj, 'matter.branch')
                    iB = find(this.aoBranches == oObj, 1);
                    
                    this.out(1, 2, 'solve-flow-rates', 'Branch: %s\t%.24f', { oObj.sName, this.afFlowRates(iB) });
                end
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
                    
                    %TODO get pressure drop distribution (depends on total
                    %     pressure drop and drop coeffs!)
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
        
        function reUpdate(this)
            % Just re-set flow rates again so branches update from IN phase
            for iR = 1:length(this.csObjUuidsToColIndex)
                oObj = this.poColIndexToObj(iR);
                
                if isa(oObj, 'matter.branch')
                    iB = find(this.aoBranches == oObj, 1);
                    
                    this.chSetBranchFlowRate{iB}(this.afFlowRates(iB), []);
                end
            end
            
        end
    end
end
