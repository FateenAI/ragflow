#!/usr/bin/env python3
"""
Render Configuration Updater

This script updates the Render YAML configuration files when new versions
or Docker configuration changes are detected from the upstream repository.
"""

import yaml
import re
import os
import sys
from pathlib import Path


def load_yaml_preserving_comments(file_path):
    """Load YAML while preserving comments and structure"""
    with open(file_path, 'r') as f:
        return f.read()


def update_version_in_content(content, new_version):
    """Update version references in YAML content"""
    # Remove 'v' prefix if present for consistency
    clean_version = new_version.lstrip('v')
    
    # Update Docker image versions
    content = re.sub(
        r'infiniflow/ragflow:v?[\d.]+(?:-\w+)?',
        f'infiniflow/ragflow:v{clean_version}',
        content
    )
    
    # Update RAGFLOW_VERSION environment variable
    content = re.sub(
        r'(key: RAGFLOW_VERSION\s*\n\s*value: ")[^"]*(")',
        f'\\g<1>{clean_version}\\g<2>',
        content
    )
    
    # Update version references in comments
    content = re.sub(
        r'# Version: v?[\d.]+',
        f'# Version: v{clean_version}',
        content
    )
    
    return content


def check_docker_compose_for_new_envs(compose_file_path):
    """Check Docker Compose file for new environment variables"""
    if not os.path.exists(compose_file_path):
        return []
    
    try:
        with open(compose_file_path, 'r') as f:
            compose_content = yaml.safe_load(f)
        
        new_envs = []
        
        # Check services for environment variables
        services = compose_content.get('services', {})
        for service_name, service_config in services.items():
            env_vars = service_config.get('environment', [])
            if isinstance(env_vars, list):
                for env in env_vars:
                    if isinstance(env, str) and '=' in env:
                        env_name = env.split('=')[0]
                        new_envs.append(f"{service_name}:{env_name}")
            elif isinstance(env_vars, dict):
                for env_name in env_vars.keys():
                    new_envs.append(f"{service_name}:{env_name}")
        
        return new_envs
    except Exception as e:
        print(f"Error parsing {compose_file_path}: {e}")
        return []


def get_current_render_envs(render_file_path):
    """Extract current environment variables from Render YAML"""
    if not os.path.exists(render_file_path):
        return set()
    
    try:
        with open(render_file_path, 'r') as f:
            render_content = yaml.safe_load(f)
        
        current_envs = set()
        services = render_content.get('services', [])
        
        for service in services:
            env_vars = service.get('envVars', [])
            for env_var in env_vars:
                if 'key' in env_var:
                    current_envs.add(env_var['key'])
        
        return current_envs
    except Exception as e:
        print(f"Error parsing {render_file_path}: {e}")
        return set()


def suggest_new_env_vars(docker_envs, render_envs):
    """Suggest new environment variables that might need to be added to Render config"""
    suggestions = []
    
    # Common environment variable mappings from Docker to Render
    docker_to_render_mappings = {
        'MYSQL_PASSWORD': 'DATABASE_URL',
        'MYSQL_HOST': 'DATABASE_URL',
        'MYSQL_PORT': 'DATABASE_URL',
        'MYSQL_USER': 'DATABASE_URL',
        'REDIS_PASSWORD': 'REDIS_URL',
        'REDIS_HOST': 'REDIS_URL',
        'REDIS_PORT': 'REDIS_URL',
    }
    
    for docker_env in docker_envs:
        service_env = docker_env.split(':', 1)
        if len(service_env) == 2:
            service, env_name = service_env
            
            # Skip if already mapped to Render equivalent
            if env_name in docker_to_render_mappings:
                render_equivalent = docker_to_render_mappings[env_name]
                if render_equivalent not in render_envs:
                    suggestions.append(f"Consider adding {render_equivalent} (maps to {env_name})")
            elif env_name not in render_envs:
                suggestions.append(f"New environment variable detected: {env_name} (from {service})")
    
    return suggestions


def update_render_files(new_version=None, check_docker_changes=False):
    """Main function to update Render configuration files"""
    render_files = ['render.yaml', 'render-simple.yaml']
    updated_files = []
    suggestions = []
    
    for render_file in render_files:
        if not os.path.exists(render_file):
            print(f"Warning: {render_file} not found, skipping...")
            continue
        
        # Load current content
        content = load_yaml_preserving_comments(render_file)
        original_content = content
        
        # Update version if provided
        if new_version:
            content = update_version_in_content(content, new_version)
            print(f"Updated version to {new_version} in {render_file}")
        
        # Check for Docker configuration changes
        if check_docker_changes:
            docker_envs = []
            for compose_file in ['docker/docker-compose.yml', 'docker/docker-compose-base.yml']:
                docker_envs.extend(check_docker_compose_for_new_envs(compose_file))
            
            render_envs = get_current_render_envs(render_file)
            file_suggestions = suggest_new_env_vars(docker_envs, render_envs)
            
            if file_suggestions:
                suggestions.extend(file_suggestions)
                print(f"Suggestions for {render_file}:")
                for suggestion in file_suggestions:
                    print(f"  - {suggestion}")
        
        # Write updated content if changed
        if content != original_content:
            with open(render_file, 'w') as f:
                f.write(content)
            updated_files.append(render_file)
            print(f"✅ Updated {render_file}")
        else:
            print(f"ℹ️  No changes needed for {render_file}")
    
    # Write suggestions to file for GitHub Actions to use
    if suggestions:
        with open('render-config-suggestions.txt', 'w') as f:
            f.write("# Render Configuration Suggestions\n\n")
            f.write("The following environment variables or configurations might need attention:\n\n")
            for suggestion in suggestions:
                f.write(f"- {suggestion}\n")
        print(f"📝 Wrote suggestions to render-config-suggestions.txt")
    
    return updated_files, suggestions


def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Update Render configuration files')
    parser.add_argument('--version', help='New version to update to')
    parser.add_argument('--check-docker', action='store_true', 
                       help='Check for Docker configuration changes')
    parser.add_argument('--dry-run', action='store_true', 
                       help='Show what would be changed without making changes')
    
    args = parser.parse_args()
    
    if args.dry_run:
        print("🔍 DRY RUN MODE - No files will be modified")
    
    try:
        updated_files, suggestions = update_render_files(
            new_version=args.version,
            check_docker_changes=args.check_docker
        )
        
        if updated_files:
            print(f"\n✅ Successfully updated {len(updated_files)} file(s): {', '.join(updated_files)}")
        else:
            print("\nℹ️  No files were updated")
        
        if suggestions:
            print(f"\n⚠️  {len(suggestions)} suggestion(s) generated - check render-config-suggestions.txt")
        
        return 0
        
    except Exception as e:
        print(f"❌ Error: {e}")
        return 1


if __name__ == '__main__':
    sys.exit(main())
