classdef incompressibleMedium < matter.manips.volume.step
    % This volume manipulator identifies a phase as incompressible. The
    % required volume calculations are handled by a compressibleMedium
    % manip. Please not that incompressible in this context only means that
    % the volume change from pressure changes is considered negligible in
    % comparison to the change the compressible phases have at the same
    % pressure change. The density for the incompressible phases is still
    % calculated through the matter table and therefore considers
    % compression!
    
    properties (SetAccess = protected, GetAccess = public)
        % We store the reference to the compressible manip, because for
        % incompressible mediums, we use the pressure of that phase as
        % pressure for the incompressible phases!
        oCompressibleManip;
    end
    
    properties (Constant)
        % Identifies this manipulator as a stationary volume manipulator
        bCompressible = false;
    end
    
    methods
        function this = incompressibleMedium(sName, oPhase, oCompressibleManip)
            %% incompressibleMedium class constructor
            % since the incompressible volume manipulator cannot be used by
            % itself, it requires the handin of the corresponding
            % compressible volume manipulator!
            this@matter.manips.volume.step(sName, oPhase);
            % bind the update function to the update of the connected
            % phase, as an update signifies a sufficiently large change in
            % mass of the incompressible phase to necessitate a volume
            % recalculation
            
            this.oCompressibleManip = oCompressibleManip;
        end
    end
    methods (Access = protected)
        function update(this, fNewVolume, fNewPressure)
            %% update
            % The incompressible manip cannot calculate changes by
            % itself, but receives the calculated changes from a
            % compressible manip within the same store. While it may seem
            % strange that an incompressible Medium is handed in a new
            % volume parameter, that does make sense because the volume can
            % change because of mass changes for the incompressible phase.
            % Also the phase is not handled as completly incompressible,
            % but rather as incompressible in comparison to other phases.
            % The density is still calculated by the matter table for the
            % current conditions allowing some degree of compression
            %
            % Input parameters:
            % fNewVolume:   The new volume for the phase of this manip in
            %               m^3 calculated by another compressibleMedium
            %               manip
            % fNewPressure: The new pressure calculated for the phase of
            %               this manip in Pa calculated by another
            %               compressible Medium manip
            if nargin > 1
                update@matter.manips.volume(this, fNewVolume, fNewPressure);
            end
        end
    end
end