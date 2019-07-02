function tCurrentSystem = createSolverStructure(tCurrentSystem, csPhases, sSystemFile)

fprintf(sSystemFile, '      function createSolverStructure(this)\n');
fprintf(sSystemFile, '          createSolverStructure@vsys(this);\n');

iActualSolvers = 0;
for iSolver = 1:length(tCurrentSystem.csSolvers)
    if ~isempty(tCurrentSystem.csSolvers{iSolver})
        % Empty fields represent parent side interface branches which are
        % deleted and therefore do not have a solver defined
        
        % More robust and transparent to use toBranches and names? Should
        % be possible by using the branch definition in csBranches, but
        % would require a function that takes this definition and
        % translates it into the branch name used by V-HAB
        % tCurrentSystem.csBranches{iSolver}
        if isempty(tCurrentSystem.csBranchNames{iSolver})
            iActualSolvers = iActualSolvers + 1;
            fprintf(sSystemFile, ['          solver.matter.', tCurrentSystem.csSolvers{iSolver},'.branch(this.aoBranches(', num2str(iActualSolvers),'));\n']);
        else
            fprintf(sSystemFile, ['          solver.matter.', tCurrentSystem.csSolvers{iSolver},'.branch(this.toBranches.', tCurrentSystem.csBranchNames{iSolver},');\n']);
        end
    end
end

fprintf(sSystemFile, '          this.setThermalSolvers();\n');

for iStore = 1:length(tCurrentSystem.Stores)
    tStore = tCurrentSystem.Stores{iStore};
    
    for iPhaseType = 1:length(csPhases)
        sPhase = (csPhases{iPhaseType});
        
        for iPhase = 1:length(tStore.(sPhase))
            
            tPhase = tStore.(sPhase){iPhase};
            
            if isfield(tPhase, 'rMaxChangeTemperature')
                
                    fprintf(sSystemFile, ['          tTimeStepProperties.rMaxChange = ', tPhase.rMaxChangeTemperature ,';\n']);
                    fprintf(sSystemFile, ['          this.toStores.', tStore.label,'.toPhases.', tPhase.label,'.oCapacity.setTimeStepProperties(tTimeStepProperties);\n']);
            end
        end
    end
end

fprintf(sSystemFile, '      end\n\n');

% end of public method section
fprintf(sSystemFile, 'end\n');
end