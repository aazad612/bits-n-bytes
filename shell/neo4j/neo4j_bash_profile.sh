#.bash_profile for neo4j
# Get the aliases and functions
if [ -f ~/.bashrc ]; then
                . ~/.bashrc
fi
PATH=$PATH:$HOME/.local/bin:$HOME/bin

NEO4J_HOME=/opt/software/neo4j/neo4j-enterprise; export NEO4j_HOME
export NH=$NEO4J_HOME

# Neo4j Configuration Files
export NC=$NH/conf

# Neo4j Log Files
export NL=$NH/logs

# Neo4j Database Files
export NEO4J_DATA=$NEO4J_HOME/data
export ND=$NEO4J_DATA

# Neo4j Backup Location to take one off backups
export NB=/opt/software/neo4j/db_backup

export PATH=$NH/bin:$PATH
