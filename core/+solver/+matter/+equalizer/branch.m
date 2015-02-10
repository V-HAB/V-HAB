classdef branch < solver.matter.base.branch
% Equalizer Solver
%
% No pressure drop or f2f components taken into account, just equalize
% pressures between phases. No own time step, updates when phases update.
%
%
%TODO
%   - check mass flows into both phases -> take into account?
%   - own time step?
    
    properties (SetAccess = protected, GetAccess = public)
        % Which maximum flow rate [kg/s] reached at ...
        fMaxFlowRate;
        % which maximum pressure [Pa]?
        fMaxPressDiff;
        
        
        % Flow rate by pressure difference - matrix for interpolation,
        % first row defines pressure difference [Pa], the second row
        % defines the according flow rate [kg/s]
        mfFlowByPressDiff; % = [ 0 10132.5; 0 0.02 ];
        
        
        %afExec = [];
        
        
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
            
            if (length(varargin) >= 3) && ~isempty(varargin{3}), fInitialFlowRate = varargin{3}; end;
            
            this@solver.matter.base.branch(oBranch, fInitialFlowRate);
            
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
            %CHECK gt or gt/eq?
            if (this.oBranch.oContainer.oTimer.fTime <= this.fLastUpdate) && ~this.bRegisteredOutdated
                %if ~this.bRegisteredOutdated, this.warn('update', 'Called a 2nd time in this time step, but prevented by bRegisteredOutdated'); end;
                %return;
            end
            
            % Get pressures
            fPressureLeft  = this.oBranch.coExmes{1}.getPortProperties();
            fPressureRight = this.oBranch.coExmes{2}.getPortProperties();
            fPressDiff     = fPressureLeft - fPressureRight;
            fFlowRate      = 0;
            iDir           = sif(fPressDiff < 0, -1, 1);
            %fPressDiff     = iDir * fPressDiff;
            
            
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
            if isnan(fFlowRate), fFlowRate = 0;
            else                 fFlowRate = sif(fPressDiff >= 0, fFlowRate, -1 * fFlowRate);
            end
            
            
            fFlowRate = (this.fOldFlowRate * this.iDampFR + fFlowRate) / (this.iDampFR + 1);
            
            this.fOldFlowRate = fFlowRate;
            
            %disp('>>>> Update equalizer');
            %disp(fFlowRate);
            %disp(this.oBranch.sName);
            
            if this.oBranch.oContainer.oTimer.iTick >= 500
                %keyboard();
            end
            
            
            % Now check if we're synced to another solver. If yes, use that
            % solver's flow rate and just add the FR here, assuming the
            % user set an accordingly lower max. FR.
            if ~isempty(this.oSyncedSolver)
                iInv = sif(this.bAlignedSolverInvertedFlowRate, -1, 1);
                
%                 if abs(fFlowRate) > abs(this.oSyncedSolver.fFlowRate) / 10
%                     fFlowRate = iDir * abs(this.oSyncedSolver.fFlowRate) / 10;
%                 end
                
                %disp('synced');
                fFlowRate = iInv * this.oSyncedSolver.fFlowRate + fFlowRate;
            end
            
            
            
            %disp([ this.oBranch.sName ' eq @' num2str(this.oBranch.oContainer.oTimer.fTime) ]);
            %this.afExec(end + 1) = this.oBranch.oContainer.oTimer.fTime;
            
            update@solver.matter.base.branch(this, fFlowRate, [], []);
        end
    end
end