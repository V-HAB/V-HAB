classdef branch < solver.matter.base.branch
% Equalizer Solver
%
% No pressure drop or f2f components taken into account, just equalize
% pressures between phases. No own time step, updates when phases update.
    
    properties (SetAccess = protected, GetAccess = public)
        % Which maximum flow rate [kg/s] reached at ...
        fMaxFlowRate;
        % which maximum pressure [Pa]?
        fMaxPressDiff;
        
        
        % Flow rate by pressure difference - matrix for interpolation,
        % first row defines pressure difference [Pa], the second row
        % defines the according flow rate [kg/s]
        mfFlowByPressDiff; % = [ 0 10132.5; 0 0.02 ];
        
        
        % If solver is aligned with another branch's solver, which means
        % the flow rate here is based on that solver's flow rate - should
        % the other solver's flow rate be inverted?
        bAlignedSolverInvertedFlowRate = false;
        
        % Need an own store for old flow rate for dampening
        fOldFlowRate = 0;
    end
    
    properties (SetAccess = public, GetAccess = public)
        iDampFR = 0;
    end
    
    
    methods
        function this = branch(oBranch, varargin)
            % Constructor for the equalizer solver.
            %
            % Parameters:
            %   - oBranch               Branch to control
            %   - mfFlowByPressDiff     Matrix with two rows and at least
            %                           two columns
            %   - fMaxPressDiff         IF given and both mfFlowByPressDiff
            %                           and this param are scalars -> used
            %                           for fMaxFlowRate/fMaxPressDiff!
            %   - fInitialFlowRate      Initial flow rate?
            
            % Initial flow rate? Set for this.fFlowRate as initial value.
            fInitialFlowRate = [];
            
            if (length(varargin) >= 3) && ~isempty(varargin{3}), fInitialFlowRate = varargin{3}; end
            
            this@solver.matter.base.branch(oBranch, fInitialFlowRate, 'manual');
            
            % Two params given, both scalars --> fMaxFlowRate/fMaxPressDiff
            if (length(varargin) == 2) && isscalar(varargin{1}) && isscalar(varargin{2})
                this.fMaxFlowRate  = varargin{1};
                this.fMaxPressDiff = varargin{2};
                
            % Matrix with two rows and at least two cols
            elseif (size(varargin{1}, 1) == 2) && (size(varargin{1}, 2) >= 2)
                this.mfFlowByPressDiff = varargin{1};
                
            end
            
            % Infinite time step ...
            this.setTimeStep(Inf);
            
            % Now we register the solver at the timer, specifying the post
            % tick level in which the solver should be executed. For more
            % information on the execution view the timer documentation.
            % Registering the solver with the timer provides a function as
            % output that can be used to bind the post tick update in a
            % tick resulting in the post tick calculation to be executed
            this.hBindPostTickUpdate      = this.oBranch.oTimer.registerPostTick(@this.update, 'matter' , 'solver');
            
        end
        
        function setProperties(this, varargin)
        %modify properties of this branch
        %write 'PropertyName' and then the Value
            i  = 1;
            while i <= length(varargin)/2
                switch  cell2mat(varargin(i*2-1))
                    case 'mfFlowByPressDiff'
                        this.mfFlowByPressDiff = cell2mat(varargin(i*2));
                    case 'fMaxPressDiff'
                        this.fMaxPressDiff = cell2mat(varargin(i*2));
                    case 'fMaxFlowRate'
                        this.fMaxFlowRate = cell2mat(varargin(i*2));
                    case 'SetOutdated'
                        if cell2mat(varargin(i*2)) == true
                            this.oBranch.setOutdated();
                        end
                end
                i = i+1;
            end
        end
        
        
        function alignWithSolver(this, oSolver, bAlignedSolverInvertedFlowRate)
            this.syncToSolver(oSolver);
            
            if nargin >= 3 && ~isempty(bAlignedSolverInvertedFlowRate)
                this.bAlignedSolverInvertedFlowRate = bAlignedSolverInvertedFlowRate;
            end
        end
    end
    
    methods (Access = protected)
        function update(this)
            % Get pressures
            fPressureLeft  = this.oBranch.coExmes{1}.getExMeProperties();
            fPressureRight = this.oBranch.coExmes{2}.getExMeProperties();
            fPressDiff     = fPressureLeft - fPressureRight;
            fFlowRate      = 0;
            
            if fPressDiff == 0
                % ...
                
            elseif ~isempty(this.mfFlowByPressDiff)
                % Max flow rate reached?
                if abs(fPressDiff) > this.mfFlowByPressDiff(1, end)
                    fFlowRate = this.mfFlowByPressDiff(2, end);
                else
                    % Interpolate with matrix
                    fFlowRate = interp1(this.mfFlowByPressDiff(1, :), this.mfFlowByPressDiff(2, :), abs(fPressDiff));
                end
                
            elseif ~isempty(this.fMaxFlowRate)
                % Max press diff reached? (choked or so ... not really)
                if abs(fPressDiff) > this.fMaxPressDiff
                    fFlowRate = this.fMaxFlowRate;
                else
                    % Interpolate with 0/0, fMaxPressDiff/fMaxFlowRate
                    fFlowRate = interp1([ 0 this.fMaxPressDiff ], [ 0 this.fMaxFlowRate ], abs(fPressDiff));
                end
            end
            
            % Flow direction / out of bounds?
            if isnan(fFlowRate)
                fFlowRate = 0;
            else
                fFlowRate = sif(fPressDiff >= 0, fFlowRate, -1 * fFlowRate);
            end
            
            fFlowRate = (this.fOldFlowRate * this.iDampFR + fFlowRate) / (this.iDampFR + 1);
            
            this.fOldFlowRate = fFlowRate;
            
            
            % Now check if we're synced to another solver. If yes, use that
            % solver's flow rate and just add the FR here, assuming the
            % user set an accordingly lower max. FR.
            if ~isempty(this.oSyncedSolver)
                if this.bAlignedSolverInvertedFlowRate
                    iInv = -1;
                else
                    iInv = 1;
                end
                fFlowRate = iInv * this.oSyncedSolver.fFlowRate + fFlowRate;
            end
            
            update@solver.matter.base.branch(this, fFlowRate);
        end
    end
end
