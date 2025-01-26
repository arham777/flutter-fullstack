from django.urls import path
from . import views

urlpatterns = [
    path('signup/', views.signup_view, name='signup'),
    path('signin/', views.signin_view, name='signin'),
    path('meals/', views.MealListCreateView.as_view(), name='meal-list-create'),
    path('meals/<int:pk>/', views.MealDetailView.as_view(), name='meal-detail'),
    path('meals/<int:meal_id>/reviews/', views.add_review, name='add-review'),
    path('meals/<int:meal_id>/reviews/<int:review_id>/', views.update_review, name='update-review'),
    path('meals/<int:meal_id>/reviews/<int:review_id>/delete/', views.delete_review, name='delete-review'),
    path('users/', views.list_users, name='list-users'),
    path('users/<int:user_id>/toggle-status/', views.toggle_user_status, name='toggle-user-status'),
]