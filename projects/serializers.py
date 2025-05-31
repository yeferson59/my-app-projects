from rest_framework import serializers
from .models import Project

class ProjectSerializer(serializers.ModelSerializer):
    class Meta:
        model = Project
        fields = ('id', 'name', 'description', 'technologies', 'created_at', 'updated_at')
        read_only_fields = ('updated_at', )
